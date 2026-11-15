package main

import (
	"context"
	"os"
	"path/filepath"
	"sync"

	"github.com/StarLoco/arena-2.70/content"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// App is the Wails-bound backend. Every exported method becomes callable from
// the frontend via the generated JS bindings. It browses the game's own content
// (server/content): the rules tables (spells, summonings, static effects) and
// the cards, which the card editor (cardedit.go) writes back.
//
// Both trees load from the checkout when the studio runs inside one, so what it
// shows is what the server will load; away from a checkout it falls back to the
// copy embedded in the binary (package content), read-only.
type App struct {
	ctx context.Context

	// paths holds where the content trees were found.
	paths Paths

	// mu guards the cached content (getters may be called concurrently from
	// the webview).
	mu sync.Mutex

	// rules is the decoded rules tree, loaded once (see ensureRules).
	rules *gamedata.RulesContent
	// cardContent is the game's own cards (S40), loaded from paths.ContentDir:
	// see cardedit.go.
	cardContent *gamedata.CardContent
}

// Paths records where the studio reads the content from.
type Paths struct {
	// ContentDir is the checkout's server/content/cards, where the game's own
	// cards live since S40 (see cardedit.go). Empty when the studio runs away
	// from a checkout: it then shows the cards embedded in the binary, read-only.
	ContentDir string `json:"contentDir"`
	// RulesDir is the checkout's server/content/rules (S43). Empty = the
	// embedded copy.
	RulesDir string `json:"rulesDir"`
}

// NewApp constructs the backend with the content trees auto-detected from the
// working directory or the executable.
func NewApp() *App {
	return &App{paths: Paths{ContentDir: detectContentDir(), RulesDir: detectRulesDir()}}
}

// startup is the Wails OnStartup hook; it captures the runtime context used by
// dialog/event APIs.
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

// GetPaths returns where the content was found, for the UI's status bar and
// overview page.
func (a *App) GetPaths() Paths {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.paths
}

// ensureRules decodes the rules content once (caller holds a.mu). Like the
// server, it must load whole: a broken file is an error, not a partial table.
func (a *App) ensureRules() error {
	if a.rules != nil {
		return nil
	}
	fsys := content.Rules
	if a.paths.RulesDir != "" {
		fsys = os.DirFS(a.paths.RulesDir)
	}
	r, err := gamedata.LoadRulesContent(fsys)
	if err != nil {
		return err
	}
	a.rules = r
	return nil
}

// Env is a small snapshot of runtime facts the UI shows in its footer.
type Env struct {
	Version string `json:"version"`
	OS      string `json:"os"`
}

// GetEnv returns build/runtime info for the status bar.
func (a *App) GetEnv() Env {
	return Env{
		Version: studioVersion,
		OS:      runtimeOS(),
	}
}

const studioVersion = "0.2.0"

// --- path detection helpers -------------------------------------------------

// detectRulesDir finds server/content/rules from the working directory or the
// executable, the same way detectContentDir finds the cards.
func detectRulesDir() string {
	for _, root := range candidateRoots() {
		for _, rel := range []string{filepath.Join("server", "content", "rules"), filepath.Join("content", "rules")} {
			dir := filepath.Join(root, rel)
			if fileExists(filepath.Join(dir, "spells.json")) {
				return dir
			}
		}
	}
	return ""
}

// candidateRoots returns directories that might be (or contain) the repo root:
// the working dir and the executable's dir, plus several parent levels of each
// (to tolerate being run from server/, cmd/studio/, a build output dir, etc.).
func candidateRoots() []string {
	var seeds []string
	if wd, err := os.Getwd(); err == nil {
		seeds = append(seeds, wd)
	}
	if exe, err := os.Executable(); err == nil {
		seeds = append(seeds, filepath.Dir(exe))
	}

	seen := map[string]bool{}
	var out []string
	for _, seed := range seeds {
		dir := seed
		for i := 0; i < 6; i++ { // walk up a few levels
			if !seen[dir] {
				seen[dir] = true
				out = append(out, dir)
			}
			parent := filepath.Dir(dir)
			if parent == dir {
				break
			}
			dir = parent
		}
	}
	return out
}

func isDir(p string) bool {
	info, err := os.Stat(p)
	return err == nil && info.IsDir()
}

func fileExists(p string) bool {
	info, err := os.Stat(p)
	return err == nil && !info.IsDir()
}
