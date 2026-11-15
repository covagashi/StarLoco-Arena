package game

import (
	"net"
	"sync"
	"time"
)

// Limits bounds what one client, or one machine, can cost the server.
//
// SECURITY: none of this existed. The accept loop took every connection
// unconditionally - no global cap, no per-IP cap, no read deadline, and nothing
// to evict a socket that connects and never speaks. Each idle connection costs
// two goroutines, ~12 KB of buffers and a 256-slot queue that can hold up to
// 16 MB of frames. Worse, opcode 1025 runs bcrypt synchronously on the session
// goroutine (~50-100 ms), so a few dozen sockets spamming logins saturate every
// core. That was the cheapest full-server denial of service remaining.
//
// A zero field means "no limit", so a zero-value Limits is inert and existing
// tests keep their old behaviour without opting in.
type Limits struct {
	MaxConns         int
	MaxConnsPerIP    int
	HandshakeTimeout time.Duration
	IdleTimeout      time.Duration
	LoginRatePerMin  int

	// NEGATIVE flags on purpose, so the zero value of Limits is fully permissive
	// and matches the numeric fields above (0 = no limit).
	//
	// I first wrote these as AutoRegister/FirstAccountAdmin and it broke every
	// end-to-end test instantly: a zero-value Limits then meant "auto-registration
	// OFF", so every test login was refused with AuthInvalidLogin. A "safe"
	// default that silently changes behaviour for every existing embedder is not
	// safe, it is just surprising - the opt-in belongs in config, which is where
	// an operator can see it.
	DisableAutoRegister      bool
	DisableFirstAccountAdmin bool

	// DemoAccounts lets the web demo's "Play" button (S44) create a demo
	// account under a generated login (IsDemoLogin), even with
	// auto-registration off; DemoPerIPHour caps how many one address
	// creates per hour (0 = no cap).
	DemoAccounts  bool
	DemoPerIPHour int
}

// IsDemoLogin reports whether a login is one the web demo generates:
// "demo-" and 20 lowercase letters or digits. Only these may become demo
// accounts, so an ordinary name can never be taken by one.
func IsDemoLogin(login string) bool {
	const prefix = "demo-"
	if len(login) != len(prefix)+20 || login[:len(prefix)] != prefix {
		return false
	}
	for _, c := range login[len(prefix):] {
		if (c < 'a' || c > 'z') && (c < '0' || c > '9') {
			return false
		}
	}
	return true
}

// AutoRegisterAllowed reports whether an unknown login may create an account.
func (l Limits) AutoRegisterAllowed() bool { return !l.DisableAutoRegister }

// FirstAccountAdminAllowed reports whether the first account on an empty database
// is granted admin.
func (l Limits) FirstAccountAdminAllowed() bool { return !l.DisableFirstAccountAdmin }

// connGuard enforces the connection caps and the login rate limit.
type connGuard struct {
	limits Limits

	mu       sync.Mutex
	total    int
	perIP    map[string]int
	loginHit map[string][]time.Time
	demoHit  map[string][]time.Time

	now func() time.Time // swappable in tests
}

func newConnGuard(l Limits) *connGuard {
	return &connGuard{
		limits:   l,
		perIP:    make(map[string]int),
		loginHit: make(map[string][]time.Time),
		demoHit:  make(map[string][]time.Time),
	}
}

func (g *connGuard) clock() time.Time {
	if g.now != nil {
		return g.now()
	}
	return time.Now()
}

// hostOf extracts the IP part of a remote address. An unparseable address is
// returned whole rather than dropped, so a caller can never accidentally bypass
// the per-IP cap by presenting something odd.
func hostOf(addr net.Addr) string {
	if addr == nil {
		return ""
	}
	if host, _, err := net.SplitHostPort(addr.String()); err == nil {
		return host
	}
	return addr.String()
}

// acquire reserves a connection slot. Returns false (with a reason) when the
// connection should be refused immediately.
func (g *connGuard) acquire(ip string) (bool, string) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.limits.MaxConns > 0 && g.total >= g.limits.MaxConns {
		return false, "server connection limit reached"
	}
	if g.limits.MaxConnsPerIP > 0 && g.perIP[ip] >= g.limits.MaxConnsPerIP {
		return false, "per-address connection limit reached"
	}
	g.total++
	g.perIP[ip]++
	return true, ""
}

// release returns a slot. Safe to call once per successful acquire.
func (g *connGuard) release(ip string) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.total > 0 {
		g.total--
	}
	if n := g.perIP[ip]; n <= 1 {
		delete(g.perIP, ip) // do not leak a map entry per address ever seen
	} else {
		g.perIP[ip] = n - 1
	}
}

// allowLogin reports whether another authentication attempt from ip is allowed
// inside the current minute. Each attempt costs a bcrypt hash, which is why this
// is rate-limited rather than merely counted.
func (g *connGuard) allowLogin(ip string) bool {
	if g.limits.LoginRatePerMin <= 0 {
		return true
	}
	g.mu.Lock()
	defer g.mu.Unlock()
	now := g.clock()
	cutoff := now.Add(-time.Minute)

	hits := g.loginHit[ip]
	kept := hits[:0]
	for _, h := range hits {
		if h.After(cutoff) {
			kept = append(kept, h)
		}
	}
	if len(kept) >= g.limits.LoginRatePerMin {
		g.loginHit[ip] = kept
		return false
	}
	g.loginHit[ip] = append(kept, now)
	return true
}

// allowDemo reports whether ip may create another demo account this hour,
// and counts it when so.
func (g *connGuard) allowDemo(ip string) bool {
	if g.limits.DemoPerIPHour <= 0 {
		return true
	}
	g.mu.Lock()
	defer g.mu.Unlock()
	now := g.clock()
	cutoff := now.Add(-time.Hour)
	kept := g.demoHit[ip][:0]
	for _, h := range g.demoHit[ip] {
		if h.After(cutoff) {
			kept = append(kept, h)
		}
	}
	if len(kept) >= g.limits.DemoPerIPHour {
		g.demoHit[ip] = kept
		return false
	}
	g.demoHit[ip] = append(kept, now)
	return true
}

// sweepLoginHits drops empty per-IP entries so a long-running server does not
// accumulate one map key per address that ever attempted a login.
func (g *connGuard) sweepLoginHits() {
	g.mu.Lock()
	defer g.mu.Unlock()
	cutoff := g.clock().Add(-time.Minute)
	for ip, hits := range g.loginHit {
		kept := hits[:0]
		for _, h := range hits {
			if h.After(cutoff) {
				kept = append(kept, h)
			}
		}
		if len(kept) == 0 {
			delete(g.loginHit, ip)
		} else {
			g.loginHit[ip] = kept
		}
	}
	hour := g.clock().Add(-time.Hour)
	for ip, hits := range g.demoHit {
		if len(hits) == 0 || !hits[len(hits)-1].After(hour) {
			delete(g.demoHit, ip)
		}
	}
}
