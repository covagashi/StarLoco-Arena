package main

import (
	"context"
	"fmt"
	"image"
	"os"
	"path/filepath"
	"sync"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// App is the Wails-bound backend. Every exported method becomes callable from
// the frontend via the generated JS bindings. It owns the resolved data
// directory and a lazily-loaded set of gamedata catalogs built over the
// existing, byte-exact decoders in internal/gamedata.
//
// The 2.70 data store (data.bdat + indexes.bdat) is opened eagerly for its
// index, then every record type is decoded once and cached. Because the 2.70
// layer has no encoder, the App exposes read-only getters only.
type App struct {
	ctx context.Context

	// paths holds the currently-selected data directory.
	paths Paths

	// mu guards the cached store + catalogs (getters may be called
	// concurrently from the webview).
	mu sync.Mutex

	// store is the open .bdat index rooted at paths.DataDir; catalogs are the
	// decoded record sets. All are rebuilt whenever the data dir changes.
	store         *gamedata.Store
	spells        *gamedata.Spells
	summonings    *gamedata.Summonings
	staticEffects *gamedata.StaticEffects
	// cardContent is the game's own cards (S40), loaded from paths.ContentDir
	// apart from the store: see cardedit.go.
	cardContent *gamedata.CardContent
	loadErr     string // last load error, surfaced to the UI
	loaded      bool   // true once a load attempt completed for the current dir

	// jars memoizes opened client asset .jar (zip) readers, keyed by absolute
	// path, for the asset/sprite browser (see assets.go).
	jars jarCache

	// spriteMeta caches the global map sprite table (elements.lib), loaded once
	// per client dir for the map-art renderer (see mapgfx.go).
	spriteMeta map[int32]spriteMeta

	// mapRenderCache memoizes composited map-art renders by world id (see
	// maprender.go), so re-selecting a world is instant.
	mapRenderCache map[int]MapRenderDTO

	// mapSprite caches decoded gfx.jar tile bitmaps by gfxId (nil = missing), so
	// repeated viewport renders while panning/zooming don't re-decode. mapBounds
	// caches each world's full art extent for auto-fit.
	mapSprite map[int]image.Image
	mapBounds map[int]MapBoundsDTO
}

// Paths records where the studio reads game data and client assets from.
type Paths struct {
	// DataDir is the directory containing data.bdat + indexes.bdat (the repo's
	// server/data folder, or the client's contents/bdata folder).
	DataDir string `json:"dataDir"`
	// ClientDir is the client's compiled/ directory whose game/contents/*.jar
	// archives hold the sprites (.tgam/.tga), animations and gui assets.
	ClientDir string `json:"clientDir"`
	// DataDirValid / ClientDirValid report whether the directory exists and
	// looks like the thing we expect (a sniff, not a guarantee).
	DataDirValid   bool `json:"dataDirValid"`
	ClientDirValid bool `json:"clientDirValid"`
	// ContentDir is the checkout's server/content/cards, where the game's own
	// cards live since S40 (see cardedit.go). Empty when the studio runs away
	// from a checkout: it then shows the cards embedded in the binary, read-only.
	ContentDir string `json:"contentDir"`
}

// NewApp constructs the backend with an auto-detected data directory
// (best-effort; the user can override it from the UI), then applies any
// persisted preference (last-used directory) from studio-config.json.
func NewApp() *App {
	a := &App{}
	a.paths = detectPaths()
	a.paths.ContentDir = detectContentDir()

	cfg := loadConfig()
	// Prefer a saved dir if it's still valid (lets the user pin a non-adjacent
	// location); otherwise keep auto-detection.
	if cfg.DataDir != "" && looksLikeDataDir(cfg.DataDir) {
		a.paths.DataDir = cfg.DataDir
		a.paths.DataDirValid = true
	}
	if cfg.ClientDir != "" && looksLikeClientDir(cfg.ClientDir) {
		a.paths.ClientDir = cfg.ClientDir
		a.paths.ClientDirValid = true
	}
	return a
}

// startup is the Wails OnStartup hook; it captures the runtime context used by
// dialog/event APIs.
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

// GetPaths returns the currently-resolved data directory and its validity, for
// the UI's status bar / settings panel.
func (a *App) GetPaths() Paths {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.paths
}

// SetDataDir points the studio at a new data directory, revalidates it, and
// drops the cached store/catalogs so the next read reloads. Returns the updated
// Paths.
func (a *App) SetDataDir(dir string) Paths {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.paths.DataDir = dir
	a.paths.DataDirValid = looksLikeDataDir(dir)
	a.invalidate()
	a.saveConfig()
	return a.paths
}

// SetClientDir points the studio at a new client-compiled directory and
// revalidates it. Changing it drops cached jar handles so assets reload from
// the new location. Returns the updated Paths.
func (a *App) SetClientDir(dir string) Paths {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.paths.ClientDir = dir
	a.paths.ClientDirValid = looksLikeClientDir(dir)
	a.jars.reset()
	a.spriteMeta = nil
	a.mapRenderCache = nil
	a.mapSprite = nil
	a.mapBounds = nil
	a.saveConfig()
	return a.paths
}

// invalidate drops all cached state (caller holds a.mu).
func (a *App) invalidate() {
	a.store = nil
	a.spells = nil
	a.summonings = nil
	a.staticEffects = nil
	a.loadErr = ""
	a.loaded = false
}

// ensureLoaded opens the store and decodes every catalog once, caching the
// result (the cards are not in it: they load from the content tree, see
// cardedit.go). It returns an error phrased for surfacing in the UI. Caller holds
// a.mu. Individual catalog failures are recorded but do not abort the others,
// so a partial store still browses.
func (a *App) ensureLoaded() error {
	if a.loaded {
		if a.loadErr != "" {
			return fmt.Errorf("%s", a.loadErr)
		}
		return nil
	}
	a.loaded = true
	if !a.paths.DataDirValid {
		a.loadErr = fmt.Sprintf("no valid data directory selected (current: %q)", a.paths.DataDir)
		return fmt.Errorf("%s", a.loadErr)
	}

	store, err := gamedata.Open(a.paths.DataDir)
	if err != nil {
		a.loadErr = err.Error()
		return err
	}
	a.store = store

	// Decode each catalog; keep the first failure but load what we can.
	var firstErr error
	if a.spells, err = store.LoadSpells(); err != nil && firstErr == nil {
		firstErr = fmt.Errorf("spells: %w", err)
	}
	if a.summonings, err = store.LoadSummonings(); err != nil && firstErr == nil {
		firstErr = fmt.Errorf("summonings: %w", err)
	}
	if a.staticEffects, err = store.LoadStaticEffects(); err != nil && firstErr == nil {
		firstErr = fmt.Errorf("static effects: %w", err)
	}
	if firstErr != nil {
		a.loadErr = firstErr.Error()
	}
	return firstErr
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

const studioVersion = "0.1.0"

// --- path detection helpers -------------------------------------------------

// detectPaths walks up from the executable and the working directory looking
// for a directory that holds the 2.70 .bdat store, so a freshly-launched studio
// usually "just works" without the user picking a folder.
func detectPaths() Paths {
	var p Paths

	roots := candidateRoots()
	// The server keeps a runtime copy of the data store at server/data; the
	// client ships its own at client/compiled/game/contents/bdata. Prefer the
	// server copy. The client assets live at client/compiled.
	dataCandidates := []string{
		"data",
		filepath.Join("server", "data"),
		filepath.Join("v2.70", "server", "data"),
		filepath.Join("client", "compiled", "game", "contents", "bdata"),
		filepath.Join("v2.70", "client", "compiled", "game", "contents", "bdata"),
	}
	clientCandidates := []string{
		filepath.Join("client", "compiled"),
		filepath.Join("v2.70", "client", "compiled"),
		"compiled",
	}
	for _, root := range roots {
		if !p.DataDirValid {
			for _, rel := range dataCandidates {
				dataDir := filepath.Join(root, rel)
				if looksLikeDataDir(dataDir) {
					p.DataDir = dataDir
					p.DataDirValid = true
					break
				}
			}
		}
		if !p.ClientDirValid {
			for _, rel := range clientCandidates {
				clientDir := filepath.Join(root, rel)
				if looksLikeClientDir(clientDir) {
					p.ClientDir = clientDir
					p.ClientDirValid = true
					break
				}
			}
		}
		if p.DataDirValid && p.ClientDirValid {
			break
		}
	}
	return p
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

// looksLikeDataDir sniffs for the signature files of the 2.70 .bdat store.
func looksLikeDataDir(dir string) bool {
	if dir == "" || !isDir(dir) {
		return false
	}
	return fileExists(filepath.Join(dir, "data.bdat")) &&
		fileExists(filepath.Join(dir, "indexes.bdat"))
}

// looksLikeClientDir sniffs for the client-compiled/ jar bundle.
func looksLikeClientDir(dir string) bool {
	if dir == "" || !isDir(dir) {
		return false
	}
	return fileExists(filepath.Join(dir, "game", "contents", "gui.jar"))
}

func isDir(p string) bool {
	info, err := os.Stat(p)
	return err == nil && info.IsDir()
}

func fileExists(p string) bool {
	info, err := os.Stat(p)
	return err == nil && !info.IsDir()
}
