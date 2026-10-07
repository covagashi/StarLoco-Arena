// Package config loads server configuration from a YAML file with environment
// variable overrides (12-factor friendly for containerized deployments).
//
// On first run the server writes a fully commented config file (see
// EnsureFile), so an operator who downloaded a release binary has a documented
// starting point without reading any docs.
package config

import (
	_ "embed"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"gopkg.in/yaml.v3"
)

// Template is the annotated config file written on first run. It documents
// every setting; keep it in sync with Config (config_template_test.go fails if
// a field is added here without a matching key in the template).
//
//go:embed config.template.yaml
var Template string

// defaultClientDownloadURL is deliberately EMPTY, and must stay that way.
//
// This project distributes a server, not a game. The DofusArena 2.70 client is
// Ankama's copyrighted work (art, audio, the executable, a bundled Oracle JRE),
// and this repository has never contained it — client/compiled/ is git-ignored,
// see AGENTS.md constraint 4. For a while the default here pointed at a
// maintainer-hosted mirror, which meant every operator who unzipped a release
// and ran it published a link to that mirror from their own public portal
// without ever choosing to. That put strangers' hosting at risk for a decision
// only the maintainer had made, so the default is now blank: the link is opt-in.
//
// An operator who has their own lawful mirror can still set
// web.client_download_url and the portal will show it. Nothing else is needed
// — the templates are already guarded on this being non-empty, so blank simply
// hides the link everywhere.
//
// Keep this in agreement with config.template.yaml (config_template_test.go's
// TestTemplateIsValid compares the whole Web block against Default()).
const defaultClientDownloadURL = ""

// Config is the full server configuration.
type Config struct {
	// Addr is the TCP listen address for the game client (default 0.0.0.0:5555).
	Addr string `yaml:"addr"`
	// DataDir holds the client game data (data.bdat + indexes.bdat).
	DataDir string `yaml:"data_dir"`
	// LogLevel: debug | info | warn | error.
	LogLevel string `yaml:"log_level"`
	// DebugAddr, when non-empty, starts a DEV-ONLY loopback HTTP endpoint for
	// live packet injection (see internal/game/debug.go). Leave empty in prod.
	DebugAddr string `yaml:"debug_addr"`

	Limits      LimitsConfig      `yaml:"limits"`
	Web         WebConfig         `yaml:"web"`
	UpdateCheck UpdateCheckConfig `yaml:"update_check"`
	DB          DBConfig          `yaml:"db"`
	World       WorldConfig       `yaml:"world"`
	Rules       RulesConfig       `yaml:"rules"`
}

// WebConfig configures the browser-facing portal where players register their
// own accounts.
type WebConfig struct {
	// Enabled serves the portal at all.
	Enabled bool `yaml:"enabled"`
	// Addr is the portal listen address. A port of 0 means "pick one": the
	// portal tries 80 first, then a short ladder of common alternatives, then
	// any free port (see internal/web.Listen).
	Addr string `yaml:"addr"`
	// RegistrationEnabled allows visitors to create accounts themselves.
	RegistrationEnabled bool `yaml:"registration_enabled"`
	// PublicHost overrides the host shown to players as the game-server address
	// (e.g. "arena.example.com"). Empty = use the host the visitor requested.
	PublicHost string `yaml:"public_host"`
	// MinLoginLength / MinPasswordLength gate new sign-ups.
	MinLoginLength    int `yaml:"min_login_length"`
	MinPasswordLength int `yaml:"min_password_length"`
	// ClientDownloadURL, when set, is shown on the portal as a link to get the
	// DofusArena 2.70 client itself — this server never bundles or commits
	// that (see AGENTS.md constraint 4), only links to it. Empty hides the
	// link entirely.
	ClientDownloadURL string `yaml:"client_download_url"`
	// ServerName brands the portal: it is the name in the header, the page
	// titles and the landing page's headline. Empty falls back to
	// "Arena Reborn".
	//
	// The fallback is deliberately NOT "DofusArena": that is Ankama's
	// trademark, and a site that brands itself with the mark of a company it
	// is not affiliated with invites a confusion claim on top of everything
	// else. Naming the game descriptively ("a server for DofusArena 2.70",
	// as the pages do) is referential use and is fine; adopting the mark as
	// your own identity is not.
	ServerName string `yaml:"server_name"`
	// ContactEmail is the address published on /legal and /privacy: the route
	// a rights holder uses to ask for material to be taken down, and the one
	// a player uses to exercise a GDPR request.
	//
	// Empty renders an explanatory line instead of a broken mailto:, but an
	// operator running a PUBLIC site should set it. A takedown page nobody
	// can write to is not a takedown process, and under GDPR a controller
	// must give data subjects a way to reach them.
	ContactEmail string `yaml:"contact_email"`
	// BrandDir is a directory of files that override the portal's built-in
	// assets, so an operator can brand the site without rebuilding the binary
	// or forking the repository.
	//
	// Any path under /static/ is looked up here FIRST and falls back to the
	// embedded copy, so dropping in logo.png, favicon.ico, arena-bg.jpg or
	// even app.css replaces just that file. The contents are hashed into the
	// asset version, so a changed logo busts the browser cache like any other
	// asset.
	//
	// This is what makes the published project white-label: what ships in git
	// carries no operator's identity, no logo and no game artwork, and every
	// deployment supplies its own.
	BrandDir string `yaml:"brand_dir"`
	// HostingProvider names the company hosting this server, shown in the
	// legal notice.
	//
	// This is not decoration. Under French law (LCEN art. 6 III-2) an operator
	// publishing in a NON-professional capacity may keep their own name off the
	// site, but only on condition that the host is named and holds their real
	// identity. Leave this empty and that anonymity is not lawful - it is just
	// an incomplete legal notice. Equivalent duties exist elsewhere in the EU.
	//
	// Give the legal entity and its address, e.g.
	// "IONOS SE, Elgendorfer Strasse 57, 56410 Montabaur, Germany".
	HostingProvider string `yaml:"hosting_provider"`
	// SessionSecret keys the HMAC that signs login-session cookies and CSRF
	// tokens. Leave it empty and the server invents a random one at startup,
	// which is fine for a local game but logs everybody out on every restart.
	// Set it to a long random string to keep sessions across restarts.
	SessionSecret string `yaml:"session_secret"`
	// SecureCookies marks session cookies "Secure", so browsers only ever send
	// them over HTTPS. Turn it on once the portal is behind TLS; leaving it on
	// for a plain-HTTP server makes logging in silently impossible, because the
	// browser accepts the cookie and then refuses to send it back.
	SecureCookies bool `yaml:"secure_cookies"`
	// DefaultLanguage is what a visitor whose browser expresses no usable
	// preference gets: "en", "fr", "es" or "de" (the four the game client
	// itself offers). An explicit choice, and then the browser's own
	// Accept-Language, both take priority over this. Empty means English.
	DefaultLanguage string `yaml:"default_language"`
	// DiscordURL is where /discord sends visitors. The game client's login
	// screen has a "Rejoindre le Discord" plaque pointing at /<lang>/discord,
	// so this can be filled in (or changed) without touching the client the
	// players already downloaded.
	DiscordURL string `yaml:"discord_url"`
	// BugReportsEnabled accepts submissions from the retail client's own bug
	// dialog at POST /<lang>/bug-report, and shows them in the admin console.
	// The endpoint is necessarily UNAUTHENTICATED - the client sends no
	// credentials with it - so it is rate limited, size capped, and can be
	// turned off entirely here.
	BugReportsEnabled bool `yaml:"bug_reports_enabled"`
	// BugReportAddr, when set, starts a SECOND listener that serves only the
	// bug-report endpoint over plain http (e.g. "0.0.0.0:80").
	//
	// This exists for one reason: the retail client bundles Java 1.6.0_07
	// (2008), which speaks no TLS newer than 1.0, so its bug dialog cannot
	// reach an https endpoint at all - it fails with "handshake_failure", and
	// the client claims success to the player before it even connects, so the
	// failure is invisible in game.
	//
	// Only that one route is served here; the portal, its login form and the
	// admin console are NOT reachable on this port. Leave it empty unless the
	// main site is https-only and you want in-game reports to work anyway.
	BugReportAddr string `yaml:"bug_report_addr"`
	// BugReportDir is where submitted screenshots are written. Relative paths
	// resolve against the working directory, like the database. Screenshots are
	// full-size JPEGs and are deliberately kept OUT of the database: MySQL's
	// default BLOB caps at 64 KB, and anything in the database lands in every
	// backup. Empty disables screenshot storage (reports are still recorded).
	BugReportDir string `yaml:"bug_report_dir"`
	// BugReportWebhook, when set, forwards every accepted bug report to that
	// URL as a Discord-compatible webhook POST ({content, embeds[]} JSON — the
	// shape Discord, Slack-compatible bots and most "incoming webhook"
	// integrations accept). The report is stored locally first; a webhook
	// failure is logged, never fatal, and never delays the player's 200/OK.
	BugReportWebhook string `yaml:"bug_report_webhook"`
	// PublicURL is the portal's address AS PLAYERS REACH IT — e.g.
	// "https://arena.example.com" or "http://203.0.113.7:8080". The Godot
	// client asks for it over the game socket (opcode 60001) to learn where to
	// POST bug reports; it cannot derive an http URL from a TCP connection.
	// Empty announces the locally-bound listener instead (fine for same-host
	// play; remote players need this set).
	PublicURL string `yaml:"public_url"`
	// TrustedProxies lists the peer addresses whose X-Forwarded-For header may
	// be believed, as IPs or CIDRs ("127.0.0.1", "10.0.0.0/8"). It is EMPTY by
	// default, and while it is empty no proxy header is trusted at all — the
	// rate limiter keys on the real peer address, which is the only safe
	// reading when anyone can dial the port directly and forge the header.
	//
	// Set it only when a reverse proxy you control terminates every request and
	// rewrites X-Forwarded-For itself (nginx's proxy_set_header). Without it,
	// a proxied portal sees every visitor as the proxy, so the per-IP sign-up
	// and sign-in limits silently become one shared, server-wide bucket.
	TrustedProxies []string `yaml:"trusted_proxies"`
}

// UpdateCheckConfig configures the startup "a newer release exists" notice.
type UpdateCheckConfig struct {
	// Enabled performs one HTTPS GET against the public GitHub releases API at
	// startup. Nothing is downloaded or installed, and no data about this
	// server is transmitted.
	Enabled bool `yaml:"enabled"`
	// TimeoutSeconds bounds that request. The check is asynchronous and never
	// delays startup.
	TimeoutSeconds int `yaml:"timeout_seconds"`
}

// WorldConfig tunes overworld behavior.
// RulesConfig holds the numbers this server INVENTED. The 2.70 client receives
// every one of them already computed, so it cannot arbitrate any of them - there
// is no retail-correct value to recover, only a value we chose. They live here so
// an operator can tune them without patching Go, and so nobody mistakes them for
// protocol facts. 0 means "use the built-in default".
type RulesConfig struct {
	// BaseXPPerFight is the XP a fight awards before morale and set bonuses.
	// Default 100.
	BaseXPPerFight int32 `yaml:"base_xp_per_fight"`
	// StandingWin / StandingLoss are the evolution-standing deltas after a ranked
	// fight. The client renders a level derived from standing, never the delta.
	// Defaults 10 and 3.
	StandingWin  int32 `yaml:"standing_win"`
	StandingLoss int32 `yaml:"standing_loss"`
	// MaxSocialListEntries caps the friend list and the ignore list. The client
	// carries the refusal (chat error 3216) but no limit of its own, so retail
	// enforced this server-side with a number that is not recoverable. Default 100.
	MaxSocialListEntries int `yaml:"max_social_list_entries"`
}
type WorldConfig struct {
	// AoIRadius is the area-of-interest radius in cells: overworld events (chat,
	// movement, spawn) only reach coaches within this distance of the source, so
	// a message never fans out to the whole map. 0 disables scoping (broadcast
	// to everyone — not recommended at scale).
	AoIRadius int `yaml:"aoi_radius"`
	// MatchBand is the strength gap two coaches may have and still be paired by
	// the matchmaker when they FIRST queue. It widens by MatchBandGrowth for
	// every second a searcher has waited, so nobody is stuck for lack of a
	// same-rated opponent. 0 disables the check entirely, which is the sensible
	// setting for a small private server where any opponent beats no opponent.
	MatchBand int `yaml:"match_band"`
	// MatchBandGrowth is how much MatchBand widens per second of waiting. 0
	// makes the band fixed, which on a quiet server can mean never matching.
	MatchBandGrowth int `yaml:"match_band_growth"`
}

// DBConfig selects and configures the database backend.
type DBConfig struct {
	// Driver: sqlite | postgres | mysql.
	Driver string `yaml:"driver"`
	// DSN is the driver-specific connection string. For sqlite it's a file path.
	DSN string `yaml:"dsn"`
	// MaxOpenConns / MaxIdleConns tune the connection pool (ignored for sqlite,
	// which is single-writer).
	MaxOpenConns int `yaml:"max_open_conns"`
	MaxIdleConns int `yaml:"max_idle_conns"`
}

// Default returns the configuration a fresh install runs with. It must stay in
// agreement with the values documented in config.template.yaml.
func Default() Config {
	return Config{
		Addr:     "0.0.0.0:5555",
		DataDir:  "data",
		LogLevel: "info",
		Web: WebConfig{
			Enabled:             true,
			Addr:                "0.0.0.0:0", // 0 = auto-select, see internal/web
			RegistrationEnabled: true,
			MinLoginLength:      3,
			MinPasswordLength:   6,
			ClientDownloadURL:   defaultClientDownloadURL,
			BugReportsEnabled:   true,
			BugReportDir:        "bugreports",
		},
		UpdateCheck: UpdateCheckConfig{
			Enabled:        true,
			TimeoutSeconds: 5,
		},
		DB: DBConfig{
			Driver:       "sqlite",
			DSN:          "arena.db",
			MaxOpenConns: 1, // sqlite is single-writer
			MaxIdleConns: 1,
		},
		World: WorldConfig{
			AoIRadius: 75, // cells; overworld events reach only nearby coaches
			// A 300-point opening band widening by 150/s means two coaches 1500
			// apart still meet after 8 seconds, so fairness never becomes a
			// deadlock on a server with few players online.
			MatchBand:       300,
			MatchBandGrowth: 150,
		},
	}
}

// EnsureFile writes the commented default config to path when no file is there
// yet, and reports whether it created one. A path pointing at an existing file
// is left untouched — the operator's edits are never overwritten.
//
// Failing to write is not fatal to the caller: the server runs fine on
// defaults, it just cannot offer the file to edit.
func EnsureFile(path string) (created bool, err error) {
	if path == "" {
		return false, nil
	}
	if _, err := os.Stat(path); err == nil {
		return false, nil // already there
	} else if !os.IsNotExist(err) {
		return false, fmt.Errorf("config: stat %q: %w", path, err)
	}

	if dir := filepath.Dir(path); dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return false, fmt.Errorf("config: create %q: %w", dir, err)
		}
	}
	// O_EXCL so two servers starting at once cannot clobber each other.
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o644)
	if err != nil {
		if os.IsExist(err) {
			return false, nil // lost the race; the other file is just as good
		}
		return false, fmt.Errorf("config: write %q: %w", path, err)
	}
	defer func() { _ = f.Close() }()
	if _, err := f.WriteString(Template); err != nil {
		return false, fmt.Errorf("config: write %q: %w", path, err)
	}
	return true, nil
}

// Load reads a YAML config file (if path is non-empty and exists), starting
// from Default(), then applies environment overrides. A missing file is not an
// error — defaults + env are used.
func Load(path string) (Config, error) {
	cfg := Default()

	if path != "" {
		data, err := os.ReadFile(path)
		if err == nil {
			if err := yaml.Unmarshal(data, &cfg); err != nil {
				return cfg, fmt.Errorf("config: parse %q: %w", path, err)
			}
		} else if !os.IsNotExist(err) {
			return cfg, fmt.Errorf("config: read %q: %w", path, err)
		}
	}

	cfg.applyEnv()
	return cfg, cfg.validate()
}

// applyEnv overrides fields from ARENA_* environment variables (for Docker).
func (c *Config) applyEnv() {
	if v := os.Getenv("ARENA_ADDR"); v != "" {
		c.Addr = v
	}
	if v := os.Getenv("ARENA_DATA_DIR"); v != "" {
		c.DataDir = v
	}
	if v := os.Getenv("ARENA_LOG_LEVEL"); v != "" {
		c.LogLevel = v
	}
	if v := os.Getenv("ARENA_DEBUG_ADDR"); v != "" {
		c.DebugAddr = v
	}
	if v, ok := envBool("ARENA_WEB_ENABLED"); ok {
		c.Web.Enabled = v
	}
	if v := os.Getenv("ARENA_WEB_ADDR"); v != "" {
		c.Web.Addr = v
	}
	if v, ok := envBool("ARENA_WEB_REGISTRATION_ENABLED"); ok {
		c.Web.RegistrationEnabled = v
	}
	if v := os.Getenv("ARENA_WEB_PUBLIC_HOST"); v != "" {
		c.Web.PublicHost = v
	}
	if v := os.Getenv("ARENA_WEB_CLIENT_DOWNLOAD_URL"); v != "" {
		c.Web.ClientDownloadURL = v
	}
	if v := os.Getenv("ARENA_WEB_CONTACT_EMAIL"); v != "" {
		c.Web.ContactEmail = v
	}
	if v := os.Getenv("ARENA_WEB_HOSTING_PROVIDER"); v != "" {
		c.Web.HostingProvider = v
	}
	if v := os.Getenv("ARENA_WEB_BRAND_DIR"); v != "" {
		c.Web.BrandDir = v
	}
	if v := os.Getenv("ARENA_WEB_SERVER_NAME"); v != "" {
		c.Web.ServerName = v
	}
	// Deliberately env-overridable: a session secret is the one web setting
	// that is a real credential, and operators should be able to inject it
	// without writing it into a config file that ends up in a backup.
	if v := os.Getenv("ARENA_WEB_SESSION_SECRET"); v != "" {
		c.Web.SessionSecret = v
	}
	if v, ok := envBool("ARENA_WEB_SECURE_COOKIES"); ok {
		c.Web.SecureCookies = v
	}
	if v := os.Getenv("ARENA_WEB_DEFAULT_LANGUAGE"); v != "" {
		c.Web.DefaultLanguage = v
	}
	if v := os.Getenv("ARENA_WEB_DISCORD_URL"); v != "" {
		c.Web.DiscordURL = v
	}
	if v, ok := envBool("ARENA_WEB_BUG_REPORTS_ENABLED"); ok {
		c.Web.BugReportsEnabled = v
	}
	if v := os.Getenv("ARENA_WEB_BUG_REPORT_DIR"); v != "" {
		c.Web.BugReportDir = v
	}
	if v := os.Getenv("ARENA_WEB_BUG_REPORT_ADDR"); v != "" {
		c.Web.BugReportAddr = v
	}
	// A webhook is a credential (anyone holding it can post to the channel),
	// so like the session secret it is deliberately env-overridable.
	if v := os.Getenv("ARENA_WEB_BUG_REPORT_WEBHOOK"); v != "" {
		c.Web.BugReportWebhook = v
	}
	if v := os.Getenv("ARENA_WEB_PUBLIC_URL"); v != "" {
		c.Web.PublicURL = v
	}
	// Comma-separated, so a container can set it without a config file.
	if v := os.Getenv("ARENA_WEB_TRUSTED_PROXIES"); v != "" {
		parts := strings.Split(v, ",")
		list := make([]string, 0, len(parts))
		for _, p := range parts {
			if p = strings.TrimSpace(p); p != "" {
				list = append(list, p)
			}
		}
		c.Web.TrustedProxies = list
	}
	if v, ok := envBool("ARENA_UPDATE_CHECK_ENABLED"); ok {
		c.UpdateCheck.Enabled = v
	}
	if v := os.Getenv("ARENA_DB_DRIVER"); v != "" {
		c.DB.Driver = v
	}
	if v := os.Getenv("ARENA_DB_DSN"); v != "" {
		c.DB.DSN = v
	}
	if v, ok := envInt("ARENA_DB_MAX_OPEN_CONNS"); ok {
		c.DB.MaxOpenConns = v
	}
	if v, ok := envInt("ARENA_DB_MAX_IDLE_CONNS"); ok {
		c.DB.MaxIdleConns = v
	}
	if v, ok := envInt("ARENA_AOI_RADIUS"); ok {
		c.World.AoIRadius = v
	}
}

func envInt(key string) (int, bool) {
	v := os.Getenv(key)
	if v == "" {
		return 0, false
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return 0, false
	}
	return n, true
}

func envBool(key string) (bool, bool) {
	v := os.Getenv(key)
	if v == "" {
		return false, false
	}
	b, err := strconv.ParseBool(v)
	if err != nil {
		return false, false
	}
	return b, true
}

func (c *Config) validate() error {
	switch strings.ToLower(c.DB.Driver) {
	case "sqlite", "postgres", "mysql":
	default:
		return fmt.Errorf("config: unknown db driver %q (want sqlite|postgres|mysql)", c.DB.Driver)
	}
	if c.DB.DSN == "" {
		return fmt.Errorf("config: db.dsn is required")
	}
	if c.Addr == "" {
		return fmt.Errorf("config: addr is required")
	}
	if c.Web.Enabled && c.Web.Addr == "" {
		return fmt.Errorf("config: web.addr is required when web.enabled is true")
	}
	if err := validateDebugAddr(c.DebugAddr); err != nil {
		return err
	}
	return nil
}

// validateDebugAddr refuses a debug endpoint that is not bound to loopback.
//
// SECURITY: the endpoint's own doc comment said it "must only ever bind to
// loopback" and nothing enforced it, while ARENA_DEBUG_ADDR makes binding
// 0.0.0.0:5599 the natural Docker mistake. It is unauthenticated and it can
// dispatch ANY opcode as ANY logged-in player (/c2s?coach=N), push arbitrary
// frames to every client, drive fight scenarios and enumerate sessions - i.e.
// full server and player takeover for anyone who can reach the port.
//
// A comment is not a control. This makes the rule refuse to start.
func validateDebugAddr(addr string) error {
	if addr == "" {
		return nil // disabled, which is the default and the right production value
	}
	host, _, err := net.SplitHostPort(addr)
	if err != nil {
		return fmt.Errorf("config: debug_addr %q is not host:port: %w", addr, err)
	}
	switch host {
	case "localhost":
		return nil
	case "":
		// ":5599" binds every interface.
		return fmt.Errorf("config: debug_addr %q binds all interfaces; the packet-"+
			"inject endpoint is unauthenticated and can act as any player. Use "+
			"127.0.0.1:PORT, or leave debug_addr empty", addr)
	}
	ip := net.ParseIP(host)
	if ip == nil || !ip.IsLoopback() {
		return fmt.Errorf("config: debug_addr %q is not a loopback address; the "+
			"packet-inject endpoint is unauthenticated and can act as any player. "+
			"Use 127.0.0.1:PORT, or leave debug_addr empty", addr)
	}
	return nil
}

// LimitsConfig bounds what a single client - or a single machine - can cost the
// server. Every field is 0-means-default, per the same convention as RulesConfig.
//
// SECURITY: none of this existed. The accept loop took every connection
// unconditionally, with no per-IP cap, no read deadline and nothing to evict a
// socket that connects and never speaks; and opcode 1025 runs bcrypt
// synchronously on the session goroutine, so a few dozen connections spamming
// logins saturated every core. That was the cheapest full-server denial of
// service left after the crash fixes.
type LimitsConfig struct {
	// MaxConnections caps concurrent game sockets server-wide. Default 2000.
	// Set to -1 to disable (not advised on a public instance).
	MaxConnections int `yaml:"max_connections"`
	// MaxConnectionsPerIP caps concurrent sockets from one address. Default 8 -
	// generous enough for a household or a shared NAT, tight enough that one
	// machine cannot exhaust the global cap alone. -1 disables.
	MaxConnectionsPerIP int `yaml:"max_connections_per_ip"`
	// HandshakeTimeoutSeconds is how long a socket may stay connected without
	// authenticating. Default 30. This is what evicts a connect-and-say-nothing
	// flood. -1 disables.
	HandshakeTimeoutSeconds int `yaml:"handshake_timeout_seconds"`
	// IdleTimeoutSeconds drops a session that sends nothing at all for this long.
	// The retail client pings well inside any sane value. Default 300.
	// -1 disables.
	IdleTimeoutSeconds int `yaml:"idle_timeout_seconds"`
	// LoginAttemptsPerMinute throttles opcode 1025 per IP, because each attempt
	// costs a bcrypt hash. Default 10. -1 disables.
	LoginAttemptsPerMinute int `yaml:"login_attempts_per_minute"`
	// AutoRegister creates an account for any unknown login presented on the GAME
	// socket. Convenient for development and a liability in production: it lets
	// anyone mint unlimited accounts, each costing a bcrypt hash.
	//
	// Defaults to TRUE only to preserve existing local workflows; an operator
	// running publicly should set it false and use the web portal, whose own
	// registration is separately gated by web.registration_enabled.
	AutoRegister *bool `yaml:"auto_register"`
	// FirstAccountIsAdmin grants admin to the first account created on an empty
	// database. Convenient locally, a race an attacker can win on a fresh public
	// instance - whoever connects first becomes administrator. Defaults to true
	// for the same reason as AutoRegister; use cmd/seedaccount and set this false
	// for anything exposed.
	FirstAccountIsAdmin *bool `yaml:"first_account_is_admin"`
}

// Limit accessors: 0 means "use the default", negative means "disabled".
func (l LimitsConfig) maxConnections() int         { return limitOr(l.MaxConnections, 2000) }
func (l LimitsConfig) maxConnectionsPerIP() int    { return limitOr(l.MaxConnectionsPerIP, 8) }
func (l LimitsConfig) handshakeTimeout() int       { return limitOr(l.HandshakeTimeoutSeconds, 30) }
func (l LimitsConfig) idleTimeout() int            { return limitOr(l.IdleTimeoutSeconds, 300) }
func (l LimitsConfig) loginAttemptsPerMinute() int { return limitOr(l.LoginAttemptsPerMinute, 10) }

// MaxConnections etc. are the exported forms the game package consumes.
func (l LimitsConfig) MaxConns() int           { return l.maxConnections() }
func (l LimitsConfig) MaxConnsPerIP() int      { return l.maxConnectionsPerIP() }
func (l LimitsConfig) HandshakeTimeout() int   { return l.handshakeTimeout() }
func (l LimitsConfig) IdleTimeout() int        { return l.idleTimeout() }
func (l LimitsConfig) LoginRatePerMinute() int { return l.loginAttemptsPerMinute() }

// AutoRegisterEnabled reports whether unknown logins may create an account.
func (l LimitsConfig) AutoRegisterEnabled() bool {
	return l.AutoRegister == nil || *l.AutoRegister
}

// FirstAccountAdmin reports whether the first account on an empty database gets
// admin rights.
func (l LimitsConfig) FirstAccountAdmin() bool {
	return l.FirstAccountIsAdmin == nil || *l.FirstAccountIsAdmin
}

func limitOr(v, def int) int {
	if v == 0 {
		return def
	}
	if v < 0 {
		return 0 // disabled
	}
	return v
}
