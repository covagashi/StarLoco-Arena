// Package web serves the browser portal bundled with the server: the public
// site players land on, the account area where they see everything the server
// stores about them, and the admin console operators run the game from.
//
// Everything ships inside the Go binary — templates, stylesheet, fonts,
// favicon — so the portal works on a machine with no internet access and needs
// no build step, no Node toolchain and no CDN.
package web

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"net/netip"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/StarLoco/arena-2.70/internal/config"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// maxLoginLen caps account names. The column holds 64, but a shorter, stricter
// bound keeps names typeable in the game client's login box.
const maxLoginLen = 24

// maxPasswordLen is bcrypt's hard limit: it refuses anything longer, so reject
// it here with a readable message rather than surfacing a library error.
const maxPasswordLen = 72

// loginRe restricts account names to characters that survive the client's
// windows-1252 wire encoding unchanged.
var loginRe = regexp.MustCompile(`^[A-Za-z0-9_-]+$`)

// accountsPerPage is the admin console's page size.
const accountsPerPage = 25

// Live is what the running game server lends the portal: counters it cannot
// read from the database, and the reference data it needs to validate what an
// admin types. Every field is optional — a nil func reads zero and a nil
// catalogue disables the checks that depend on it — so tests and a server
// started without game data can construct the portal without stubbing anything.
type Live struct {
	// PlayersOnline is the number of coaches currently in the world.
	PlayersOnline func() int
	// ActiveFights is the number of fights in progress.
	ActiveFights func() int
	// TournamentDefs is the decoded type-1000 catalogue. The tournament editor
	// validates against it: a definition id the client does not have crashes
	// the client, so an admin must not be able to save one.
	TournamentDefs *gamedata.Tournaments
	// TournamentRegistrations reports how many coaches have signed up for a
	// tournament, by wire id. Registrations are cached in the game process,
	// so the portal cannot query them directly.
	TournamentRegistrations func(wireID int64) int
}

// Server is the portal. Construct it with New and hand Handler() to net/http.
type Server struct {
	store *store.Store
	cfg   config.WebConfig
	log   *slog.Logger

	// gameAddr is the configured game listen address, used to tell players
	// what to put in their client config.
	gameAddr string
	live     Live
	// tournamentDefs mirrors live.TournamentDefs; see tournaments.go.
	tournamentDefs *gamedata.Tournaments

	codec *sessionCodec
	tmpl  map[string]*templateSet
	cat   catalog

	// brand and assetVersion describe the operator's own branding, read once
	// from web.brand_dir at startup. assetVersion folds those files into the
	// cache-busting hash so a replaced logo actually reaches browsers.
	brand        brandAssets
	assetVersion string

	// limiter caps account creation, loginLimiter caps sign-in attempts. They
	// are separate because the right allowance differs by an order of
	// magnitude: creating ten accounts an hour from one address is already
	// suspicious, whereas mistyping a password ten times in an evening is not.
	limiter      *limiter
	loginLimiter *limiter
	// bugLimiter caps bug-report submissions. That endpoint carries no
	// credential at all (the client sends none), so it needs its own ceiling.
	bugLimiter *limiter
	started    time.Time

	// webhookClient POSTs bug reports to bug_report_webhook. nil = the default
	// 10s-timeout client; tests swap it for one pointed at httptest.
	webhookClient *http.Client

	// trustedProxies are the reverse proxies allowed to tell us, via
	// X-Forwarded-For, who the real visitor is. Empty means "believe nobody",
	// which is the safe default for a directly-reachable portal.
	trustedProxies []netip.Prefix
}

// New builds the portal. It fails only on a programming error — a template
// that does not parse — so a caller can treat an error as fatal.
func New(st *store.Store, cfg config.WebConfig, gameAddr string, live Live, log *slog.Logger) (*Server, error) {
	if log == nil {
		log = slog.Default()
	}
	if cfg.MinLoginLength <= 0 {
		cfg.MinLoginLength = 3
	}
	if cfg.MinPasswordLength <= 0 {
		cfg.MinPasswordLength = 6
	}

	codec, ephemeral, err := newSessionCodec(cfg.SessionSecret)
	if err != nil {
		return nil, err
	}
	if ephemeral {
		log.Warn("web: no session secret configured, using a random one — " +
			"everybody will be signed out when the server restarts " +
			"(set web.session_secret to avoid this)")
	}

	cat, err := loadCatalog()
	if err != nil {
		return nil, err
	}
	tmpl, err := parseAllTemplates(cat)
	if err != nil {
		return nil, err
	}

	trusted, err := parseTrustedProxies(cfg.TrustedProxies)
	if err != nil {
		return nil, err
	}
	if len(trusted) > 0 {
		log.Info("web: trusting forwarded client addresses from reverse proxies",
			"proxies", cfg.TrustedProxies)
	}

	brand := scanBrand(cfg.BrandDir)
	if cfg.BrandDir != "" {
		log.Info("web: serving operator branding", "dir", cfg.BrandDir,
			"logo", brand.Logo, "favicon", brand.Favicon)
	} else {
		log.Info("web: no web.brand_dir configured - the portal will render " +
			"unbranded (server name as text, no logo or favicon)")
	}

	return &Server{
		store:          st,
		cfg:            cfg,
		log:            log,
		gameAddr:       gameAddr,
		live:           live,
		tournamentDefs: live.TournamentDefs,
		codec:          codec,
		tmpl:           tmpl,
		cat:            cat,
		brand:          brand,
		assetVersion:   brandAssetVersion(cfg.BrandDir),
		// A generous allowance for a household or guild sharing one address,
		// but low enough that the form cannot be used to hammer the database.
		limiter: newLimiter(10, time.Hour),
		// Brute-force guard. Passwords are bcrypt-hashed, so an online guess
		// already costs ~100ms of CPU; this stops that CPU being the whole
		// server's.
		loginLimiter: newLimiter(20, 15*time.Minute),
		// Generous for a player hitting a genuinely broken feature repeatedly,
		// low enough that an unauthenticated endpoint which writes a row and a
		// file cannot be used to fill the disk.
		bugLimiter:     newLimiter(20, time.Hour),
		started:        time.Now(),
		trustedProxies: trusted,
	}, nil
}

// Handler returns the portal's routes.
//
// Go 1.22 method+path patterns let GET and POST on the same URL map to
// different handlers, so no handler starts with a method switch.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()

	// Static assets: the operator's brand_dir where it supplies a file, the
	// embedded stylesheet and fonts otherwise.
	static := staticFileServer(s.cfg.BrandDir)
	mux.Handle("GET /static/", http.StripPrefix("/static/", cacheStatic(static)))
	// Served directly rather than redirected. Browsers request this path
	// implicitly and cache a 301 here very aggressively, so the old permanent
	// redirect to favicon.svg outlived the file it pointed at.
	mux.HandleFunc("GET /favicon.ico", func(w http.ResponseWriter, r *http.Request) {
		http.StripPrefix("/", cacheStatic(static)).ServeHTTP(w, r)
	})

	// Public.
	mux.HandleFunc("GET /{$}", s.handleIndex) // {$} = exactly "/", not a catch-all
	mux.HandleFunc("GET /status", s.handleStatus)
	mux.HandleFunc("GET /ladder", s.handleLadder)
	mux.HandleFunc("GET /login", s.handleLoginForm)
	mux.HandleFunc("POST /login", s.handleLoginSubmit)
	mux.HandleFunc("GET /register", s.handleRegisterForm)
	mux.HandleFunc("POST /register", s.handleRegisterSubmit)
	mux.HandleFunc("POST /logout", s.handleLogout)
	// Legal pages. Public and crawlable on purpose: a non-affiliation notice
	// nobody can find does not do the job it exists to do, and a GDPR notice
	// has to be reachable before somebody signs up, not after.
	mux.HandleFunc("GET /legal", s.handleLegal)
	mux.HandleFunc("GET /privacy", s.handlePrivacy)
	mux.HandleFunc("GET /terms", s.handleTerms)
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = w.Write([]byte("ok"))
	})

	// Signed in (any account).
	mux.HandleFunc("GET /account", s.requireUser(s.handleAccount))
	mux.HandleFunc("GET /account/password", s.requireUser(s.handlePasswordForm))
	mux.HandleFunc("POST /account/password", s.requireUser(s.handlePasswordSubmit))
	// Self-service erasure. The admin console can already delete an account,
	// but GDPR art. 17 is the data subject's right, so it cannot require
	// asking an operator.
	mux.HandleFunc("GET /account/delete", s.requireUser(s.handleDeleteAccountForm))
	mux.HandleFunc("POST /account/delete", s.requireUser(s.handleDeleteAccountSubmit))

	// Admin console. Starting impersonation is admin-gated; stopping it is
	// not, so somebody who is impersonating can always get back to themselves
	// even if their admin rights were revoked while they were away.
	mux.HandleFunc("GET /admin", s.requireAdmin(s.handleAdminDashboard))
	mux.HandleFunc("GET /admin/accounts", s.requireAdmin(s.handleAdminAccounts))
	mux.HandleFunc("GET /admin/accounts/new", s.requireAdmin(s.handleAdminCreateForm))
	mux.HandleFunc("POST /admin/accounts/new", s.requireAdmin(s.handleAdminCreateSubmit))
	mux.HandleFunc("GET /admin/accounts/{id}", s.requireAdmin(s.handleAdminAccountDetail))
	mux.HandleFunc("POST /admin/accounts/{id}/delete", s.requireAdmin(s.handleAdminDelete))
	mux.HandleFunc("POST /admin/accounts/{id}/toggle-admin", s.requireAdmin(s.handleAdminToggleAdmin))
	mux.HandleFunc("POST /admin/accounts/{id}/impersonate", s.requireAdmin(s.handleImpersonateStart))
	mux.HandleFunc("GET /admin/tournaments", s.requireAdmin(s.handleAdminTournaments))
	mux.HandleFunc("GET /admin/tournaments/new", s.requireAdmin(s.handleAdminTournamentNew))
	mux.HandleFunc("POST /admin/tournaments/new", s.requireAdmin(s.handleAdminTournamentCreate))
	mux.HandleFunc("GET /admin/tournaments/{id}", s.requireAdmin(s.handleAdminTournamentEdit))
	mux.HandleFunc("POST /admin/tournaments/{id}", s.requireAdmin(s.handleAdminTournamentSave))
	mux.HandleFunc("POST /admin/tournaments/{id}/delete", s.requireAdmin(s.handleAdminTournamentDelete))
	mux.HandleFunc("POST /admin/tournaments/{id}/toggle", s.requireAdmin(s.handleAdminTournamentToggle))
	mux.HandleFunc("GET /admin/bugs", s.requireAdmin(s.handleAdminBugs))
	mux.HandleFunc("GET /admin/bugs/{id}", s.requireAdmin(s.handleAdminBugDetail))
	mux.HandleFunc("GET /admin/bugs/{id}/screenshot", s.requireAdmin(s.handleAdminBugScreenshot))
	mux.HandleFunc("POST /admin/bugs/{id}/resolve", s.requireAdmin(s.handleAdminBugResolve))
	mux.HandleFunc("POST /admin/bugs/{id}/delete", s.requireAdmin(s.handleAdminBugDelete))
	mux.HandleFunc("GET /admin/monitoring", s.requireAdmin(s.handleAdminMonitoring))
	mux.HandleFunc("GET /admin/monitoring/pprof/{profile}", s.requireAdmin(s.handleAdminPprof))
	mux.HandleFunc("POST /impersonate/stop", s.handleImpersonateStop)

	// The retail client's bug dialog posts to <bugReportURL><lang>/bug-report,
	// building that path itself (aOG.a), so the language segment is whatever
	// the player's client is set to and has to be a wildcard.
	mux.HandleFunc("POST /{lang}/bug-report", s.handleBugReport)

	// The login screen's two plaques (avv_0.showUrl, repointed in core.jar).
	// The client builds base + language + path, so the language-prefixed forms
	// are served too.
	//
	// The four languages are listed rather than matched with "/{lang}/" on
	// purpose: a GET wildcard there is ambiguous with "GET /static/" (both
	// match "/static/discord") and Go's mux panics at registration. The client
	// only ever offers these four - they are the radio buttons on its own login
	// dialog - so enumerating them is exact rather than a workaround. The
	// bug-report route can keep its wildcard because it is POST-only and so
	// cannot collide with the static handler.
	mux.HandleFunc("GET /robots.txt", s.handleRobots)
	mux.HandleFunc("GET /sitemap.xml", s.handleSitemap)
	mux.HandleFunc("GET /lang", s.handleSetLanguage)
	mux.HandleFunc("GET /discord", s.handleDiscord)

	// localeRoutes sits OUTSIDE the mux: it rewrites /fr/ladder to /ladder plus
	// a language before any route is matched, so every page keeps one handler
	// and one registration while still having a distinct URL per language for
	// crawlers to index.
	return securityHeadersHSTS(s.localeRoutes(mux), s.cfg.SecureCookies)
}

// serverName is the branding shown in the header and the page titles.
//
// The fallback is a generic placeholder on purpose, and is neither "DofusArena"
// nor any existing server's name. DofusArena is Ankama's trademark - describing
// what the server runs is referential use and is fine, but taking the mark as
// the site's own identity invites a confusion claim. And defaulting to some
// other operator's brand would make every fork impersonate them.
//
// Set web.server_name. What ships is deliberately anonymous.
func (s *Server) serverName() string {
	if n := strings.TrimSpace(s.cfg.ServerName); n != "" {
		return n
	}
	return "Arena Server"
}

func (s *Server) playersOnline() int {
	if s.live.PlayersOnline == nil {
		return 0
	}
	return s.live.PlayersOnline()
}

func (s *Server) activeFights() int {
	if s.live.ActiveFights == nil {
		return 0
	}
	return s.live.ActiveFights()
}

// uptimeSeconds is how long the portal (and so the server) has been running.
func (s *Server) uptimeSeconds() int64 {
	return int64(time.Since(s.started) / time.Second)
}

// gameAddress works out what players should type into their client. The
// configured listen address is usually a wildcard (0.0.0.0), which is useless
// to a player, so the host the visitor already reached us on is substituted.
func (s *Server) gameAddress(r *http.Request) string {
	_, port, err := net.SplitHostPort(s.gameAddr)
	if err != nil || port == "" {
		port = "5555"
	}

	host := s.cfg.PublicHost
	if host == "" {
		if h, _, err := net.SplitHostPort(s.gameAddr); err == nil && !isWildcard(h) {
			host = h
		}
	}
	if host == "" && r != nil {
		if h, _, err := net.SplitHostPort(r.Host); err == nil {
			host = h
		} else {
			host = r.Host
		}
	}
	if host == "" {
		host = "127.0.0.1"
	}
	return net.JoinHostPort(host, port)
}

func isWildcard(host string) bool {
	return host == "" || host == "0.0.0.0" || host == "::" || host == "[::]"
}

// validate applies the sign-up policy shared by public registration and the
// admin console's create form.
func (s *Server) validate(login, password string) error {
	switch {
	case login == "":
		return errors.New("Please choose an account name.")
	case len(login) < s.cfg.MinLoginLength:
		return fmt.Errorf("The account name must be at least %d characters.", s.cfg.MinLoginLength)
	case len(login) > maxLoginLen:
		return fmt.Errorf("The account name must be at most %d characters.", maxLoginLen)
	case !loginRe.MatchString(login):
		return errors.New("The account name may only contain letters, digits, - and _.")
	case len(password) < s.cfg.MinPasswordLength:
		return fmt.Errorf("The password must be at least %d characters.", s.cfg.MinPasswordLength)
	case len(password) > maxPasswordLen:
		return fmt.Errorf("The password must be at most %d characters.", maxPasswordLen)
	}
	return nil
}

// redirect sends a see-other, the correct code after a successful POST: it
// makes the browser follow up with a GET, so a refresh cannot re-submit.
func redirect(w http.ResponseWriter, r *http.Request, to string) {
	http.Redirect(w, r, to, http.StatusSeeOther)
}

// securityHeaders applies a conservative baseline.
//
// The portal serves only its own assets and has no inline scripts, so the
// policy can forbid scripts outright. That is a real mitigation rather than a
// formality: it means a stored-XSS bug in, say, a coach name could not execute.
func securityHeaders(next http.Handler) http.Handler {
	return securityHeadersHSTS(next, false)
}

// securityHeadersHSTS is securityHeaders plus Strict-Transport-Security when the
// operator has declared the portal is served over HTTPS.
//
// HSTS is gated on secure_cookies rather than emitted unconditionally because
// sending it over plain HTTP is at best ignored and at worst locks a local
// developer out of their own http://localhost portal for a year. secure_cookies
// is the existing "this deployment is HTTPS" switch, so one flag governs both
// rather than adding a second one an operator can set inconsistently.
func securityHeadersHSTS(next http.Handler, https bool) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()
		h.Set("Content-Security-Policy",
			"default-src 'none'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; "+
				"font-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'")
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("Referrer-Policy", "same-origin")
		if https {
			// One year, subdomains included. No preload directive: preloading is a
			// commitment the operator must opt into deliberately, since removal
			// takes months.
			h.Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		}
		next.ServeHTTP(w, r)
	})
}

// cacheStatic lets browsers keep assets they already have.
//
// Anything whose URL identifies its content can be cached forever: the
// stylesheet carries a ?v= content hash (see assetVersion), and a font is
// immutable in practice because changing one means shipping a differently
// named file. Everything else gets a few minutes — long enough to serve a page
// load, short enough that a fix is never more than a coffee away.
//
// The long window used to apply to *everything*, unfingerprinted, which made
// the portal effectively unfixable: a corrected stylesheet could not reach a
// browser that had already cached the broken one.
func cacheStatic(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fingerprinted := r.URL.Query().Get("v") != "" || strings.HasSuffix(r.URL.Path, ".woff2")
		if fingerprinted {
			w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
		} else {
			w.Header().Set("Cache-Control", "public, max-age=300")
		}
		next.ServeHTTP(w, r)
	})
}

// sameOrigin reports whether a state-changing request came from our own page.
// Browsers always send Origin on cross-origin form posts, so an Origin that
// disagrees with Host is a cross-site submission. A missing Origin is accepted:
// same-origin form posts may omit it, and non-browser clients (curl) are not
// the threat model here.
func sameOrigin(r *http.Request) bool {
	origin := r.Header.Get("Origin")
	if origin == "" || origin == "null" {
		return true
	}
	u, err := url.Parse(origin)
	if err != nil {
		return false
	}
	return strings.EqualFold(u.Host, r.Host)
}

// peerIP is the address the connection actually came from.
func peerIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

// parseTrustedProxies turns the configured IPs/CIDRs into prefixes, rejecting
// anything unparseable at startup rather than silently trusting nothing (a
// typo here would quietly reinstate the shared-bucket bug it exists to fix).
func parseTrustedProxies(list []string) ([]netip.Prefix, error) {
	out := make([]netip.Prefix, 0, len(list))
	for _, raw := range list {
		raw = strings.TrimSpace(raw)
		if raw == "" {
			continue
		}
		if p, err := netip.ParsePrefix(raw); err == nil {
			out = append(out, p)
			continue
		}
		addr, err := netip.ParseAddr(raw)
		if err != nil {
			return nil, fmt.Errorf("web: trusted_proxies: %q is not an IP or CIDR", raw)
		}
		addr = addr.Unmap()
		out = append(out, netip.PrefixFrom(addr, addr.BitLen()))
	}
	return out, nil
}

// isTrustedProxy reports whether addr is one of the reverse proxies we run.
func (s *Server) isTrustedProxy(addr netip.Addr) bool {
	addr = addr.Unmap()
	for _, p := range s.trustedProxies {
		if p.Contains(addr) {
			return true
		}
	}
	return false
}

// clientIP extracts the address the rate limiter keys on.
//
// Proxy headers are believed ONLY when the request genuinely arrived from a
// configured trusted proxy; otherwise they are attacker-controlled and
// trusting them would defeat the rate limit entirely. That is why
// web.trusted_proxies is empty by default: a directly-reachable portal must
// keep keying on the real peer.
//
// When the header is believed, the client is the right-most X-Forwarded-For
// entry that is not itself one of our proxies. Entries to the right of it were
// appended by hops we control and are therefore known-good; everything to its
// left is whatever the original caller chose to claim, and is ignored.
func (s *Server) clientIP(r *http.Request) string {
	peer := peerIP(r)
	if len(s.trustedProxies) == 0 {
		return peer
	}
	addr, err := netip.ParseAddr(peer)
	if err != nil || !s.isTrustedProxy(addr) {
		return peer
	}
	fwd := r.Header.Get("X-Forwarded-For")
	if fwd == "" {
		return peer
	}
	hops := strings.Split(fwd, ",")
	for i := len(hops) - 1; i >= 0; i-- {
		hop, err := netip.ParseAddr(strings.TrimSpace(hops[i]))
		if err != nil {
			// A malformed hop means we can no longer tell who appended what,
			// so stop rather than skip past it and trust something further left.
			break
		}
		if !s.isTrustedProxy(hop) {
			return hop.Unmap().String()
		}
	}
	return peer
}

func isDuplicate(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "unique constraint") || // sqlite
		strings.Contains(msg, "duplicate key") || // postgres
		strings.Contains(msg, "duplicate entry") // mysql
}

// idParam reads a {id} path value.
func idParam(r *http.Request) (uint, bool) {
	n, err := strconv.ParseUint(r.PathValue("id"), 10, 64)
	if err != nil || n == 0 {
		return 0, false
	}
	return uint(n), true
}

// ---------------------------------------------------------------------------
// Rate limiting
// ---------------------------------------------------------------------------

// limiter is a fixed-window counter keyed by client address.
type limiter struct {
	mu     sync.Mutex
	hits   map[string][]time.Time
	max    int
	window time.Duration
	// now is swappable for tests.
	now func() time.Time
}

// maxTrackedClients bounds the limiter's memory. Reaching it means either a
// very popular server or a distributed abuse attempt; either way, dropping the
// oldest state is preferable to growing without limit.
const maxTrackedClients = 4096

func newLimiter(max int, window time.Duration) *limiter {
	return &limiter{
		hits:   make(map[string][]time.Time),
		max:    max,
		window: window,
		now:    time.Now,
	}
}

func (l *limiter) allow(key string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := l.now()
	cutoff := now.Add(-l.window)

	if len(l.hits) > maxTrackedClients {
		l.pruneLocked(cutoff)
		if len(l.hits) > maxTrackedClients {
			l.hits = make(map[string][]time.Time)
		}
	}

	kept := l.hits[key][:0]
	for _, t := range l.hits[key] {
		if t.After(cutoff) {
			kept = append(kept, t)
		}
	}
	if len(kept) >= l.max {
		l.hits[key] = kept
		return false
	}
	l.hits[key] = append(kept, now)
	return true
}

func (l *limiter) pruneLocked(cutoff time.Time) {
	for k, times := range l.hits {
		kept := times[:0]
		for _, t := range times {
			if t.After(cutoff) {
				kept = append(kept, t)
			}
		}
		if len(kept) == 0 {
			delete(l.hits, k)
		} else {
			l.hits[k] = kept
		}
	}
}

// ---------------------------------------------------------------------------
// Listening
// ---------------------------------------------------------------------------

// autoPorts is the ladder tried when the configured port is 0. Port 80 first so
// players can reach the portal without typing a port at all; 0 last means "any
// free port the OS will give us", which cannot fail.
var autoPorts = []string{"80", "8080", "8090", "3000", "5000", "0"}

// Listen binds the portal's listener.
//
// A port of 0 means "choose for me" and walks autoPorts. An explicit port is
// tried first and, if it is unavailable, falls back to the same ladder rather
// than refusing to start — a busy port should not cost the operator their
// server. Compare the returned listener's port with the requested one to detect
// that case.
func Listen(addr string) (net.Listener, error) {
	host, port, err := net.SplitHostPort(addr)
	if err != nil {
		// Tolerate a bare host or a bare port.
		if p, convErr := strconv.Atoi(strings.TrimPrefix(addr, ":")); convErr == nil {
			host, port = "", strconv.Itoa(p)
		} else {
			host, port = addr, "0"
		}
	}

	if port != "0" && port != "" {
		if ln, err := net.Listen("tcp", net.JoinHostPort(host, port)); err == nil {
			return ln, nil
		}
	}
	var lastErr error
	for _, p := range autoPorts {
		ln, err := net.Listen("tcp", net.JoinHostPort(host, p))
		if err == nil {
			return ln, nil
		}
		lastErr = err
	}
	return nil, fmt.Errorf("web: no port available for %q: %w", addr, lastErr)
}

// Port returns the numeric port a listener is bound to.
func Port(ln net.Listener) int {
	if tcp, ok := ln.Addr().(*net.TCPAddr); ok {
		return tcp.Port
	}
	return 0
}

// URL renders the address to show an operator in the console.
func URL(ln net.Listener) string { return urlForPort(Port(ln)) }

// urlForPort omits the port when it is the browser default, so the operator
// sees the shortest thing a player can actually type.
func urlForPort(port int) string {
	if port == 80 {
		return "http://localhost"
	}
	return fmt.Sprintf("http://localhost:%d", port)
}

// BugReportHandler is a deliberately tiny handler that serves ONLY the client's
// bug-report endpoint and 404s everything else.
//
// It exists because the retail client bundles Java 1.6.0_07 (2008), which speaks
// nothing newer than TLS 1.0. Any CDN or reverse proxy worth using requires
// TLS 1.2+, so the client's bug dialog CANNOT reach an https endpoint - it dies
// with "Received fatal alert: handshake_failure", and because the client tells
// the player "sent" before it even opens the connection, the failure is
// completely invisible in game.
//
// The only way to accept those reports is a plain-http listener. Serving the
// whole portal there would put the login form and the admin console on an
// unencrypted port, so this exposes exactly one route and nothing else: no
// session is read, no cookie is set, no template is rendered.
func (s *Server) BugReportHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /{lang}/bug-report", s.handleBugReport)
	return securityHeaders(mux)
}

// ServeBugReports runs the plain-http bug-report listener until ctx is cancelled.
func (s *Server) ServeBugReports(ctx context.Context, ln net.Listener) error {
	return s.serveOn(ctx, ln, s.BugReportHandler())
}

// Serve runs the portal on ln until ctx is cancelled, then shuts it down.
func (s *Server) Serve(ctx context.Context, ln net.Listener) error {
	return s.serveOn(ctx, ln, s.Handler())
}

func (s *Server) serveOn(ctx context.Context, ln net.Listener, h http.Handler) error {
	srv := &http.Server{
		Handler: h,
		// The portal is on a hostile-by-default network; bound every phase so a
		// stuck client cannot pin a connection open indefinitely.
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	done := make(chan struct{})
	go func() {
		defer close(done)
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = srv.Shutdown(shutdownCtx)
	}()

	err := srv.Serve(ln)
	<-done
	if errors.Is(err, http.ErrServerClosed) {
		return nil
	}
	return err
}
