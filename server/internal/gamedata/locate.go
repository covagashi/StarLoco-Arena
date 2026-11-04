package gamedata

import (
	"os"
	"path/filepath"
	"runtime"
)

// Location is a resolved pair of game-data directories.
//
// The client keeps these in two SEPARATE places under its contents folder —
// the record store in bdata/, the arenas in maps/ — so a single path is not
// enough to describe where the data is. Either field may be empty: a server
// with records but no arenas still runs (it falls back to the built-in arena),
// and that is a much better outcome than refusing to start.
type Location struct {
	// BdatDir contains data.bdat and indexes.bdat.
	BdatDir string
	// MapsRoot is the directory CONTAINING maps/ (not maps/ itself), because
	// LoadWorldTopology and LoadEnvWorld join "maps" themselves.
	MapsRoot string
	// Root is the directory that matched, for reporting to the operator.
	Root string
}

// abs makes a path absolute for display and for immunity to any later change
// of working directory. A path that cannot be resolved is returned unchanged
// rather than discarded.
func abs(p string) string {
	if p == "" {
		return ""
	}
	if a, err := filepath.Abs(p); err == nil {
		return a
	}
	return p
}

// Complete reports whether both halves were found.
func (l Location) Complete() bool { return l.BdatDir != "" && l.MapsRoot != "" }

// Found reports whether anything usable was found at all.
func (l Location) Found() bool { return l.BdatDir != "" || l.MapsRoot != "" }

// hasBdat reports whether dir directly holds the record store.
func hasBdat(dir string) bool {
	if dir == "" {
		return false
	}
	for _, f := range []string{"data.bdat", "indexes.bdat"} {
		if st, err := os.Stat(filepath.Join(dir, f)); err != nil || st.IsDir() {
			return false
		}
	}
	return true
}

// hasMaps reports whether dir holds a maps/ subtree with arenas in it.
func hasMaps(dir string) bool {
	if dir == "" {
		return false
	}
	st, err := os.Stat(filepath.Join(dir, "maps", "fight"))
	return err == nil && st.IsDir()
}

// Resolve interprets root as any of the shapes the data legitimately takes,
// and returns whichever halves it can find.
//
// Supported layouts, in order of preference:
//
//	<root>/data.bdat          + <root>/maps/          "merged" server data dir
//	<root>/bdata/data.bdat    + <root>/maps/          the client's contents/ dir
//	<root>/contents/bdata/... + <root>/contents/maps/ the client's game/ dir
//	<root>/game/contents/...                          the client's install root
//
// Accepting all four means an operator can simply point the server at their
// DofusArena folder instead of hand-merging two directories into one.
func Resolve(root string) Location {
	if root == "" {
		return Location{}
	}
	// Candidate bases to inspect, nearest first.
	bases := []string{
		root,
		filepath.Join(root, "contents"),
		filepath.Join(root, "game", "contents"),
	}

	var out Location
	for _, base := range bases {
		if out.BdatDir == "" {
			switch {
			case hasBdat(base):
				out.BdatDir = abs(base)
			case hasBdat(filepath.Join(base, "bdata")):
				out.BdatDir = abs(filepath.Join(base, "bdata"))
			}
		}
		if out.MapsRoot == "" && hasMaps(base) {
			out.MapsRoot = abs(base)
		}
		if out.Complete() {
			out.Root = abs(root)
			return out
		}
	}
	if out.Found() {
		out.Root = abs(root)
	}
	return out
}

// Discover locates the game data, starting from the configured path and
// falling back to the places the client is normally installed.
//
// If the configured path yields records but no arenas (the common result of
// copying only the bdata folder, which is what the old instructions said to
// do), the remaining candidates are still searched for the missing half.
func Discover(configured string) Location {
	var out Location

	for _, root := range candidateRoots(configured) {
		loc := Resolve(root)
		if loc.BdatDir != "" && out.BdatDir == "" {
			out.BdatDir = loc.BdatDir
			if out.Root == "" {
				out.Root = loc.Root
			}
		}
		if loc.MapsRoot != "" && out.MapsRoot == "" {
			out.MapsRoot = loc.MapsRoot
			if out.Root == "" {
				out.Root = loc.Root
			}
		}
		if out.Complete() {
			break
		}
	}
	return out
}

// candidateRoots is the ordered search path: the operator's choice first, then
// locations relative to the executable and working directory, then the usual
// install locations for the retail client.
func candidateRoots(configured string) []string {
	var roots []string
	// Deduplicate on the RESOLVED path: "data" and "<exedir>/data" are
	// different strings that frequently name the same directory, and listing
	// it twice in the "looked in" message just looks broken.
	seen := make(map[string]bool)
	add := func(p string) {
		if p == "" {
			return
		}
		key := abs(filepath.Clean(p))
		if seen[key] {
			return
		}
		seen[key] = true
		roots = append(roots, p)
	}

	// 1. Whatever the config or --data flag said.
	add(configured)

	// 2. Beside the executable, which is where a downloaded release runs from.
	//    (When the config holds a relative path, this makes double-clicking the
	//    binary work regardless of the shell's working directory.)
	if exe, err := os.Executable(); err == nil {
		exeDir := filepath.Dir(exe)
		add(filepath.Join(exeDir, "data"))
		add(filepath.Join(exeDir, "data-dist"))
		add(exeDir)
		// A release unzipped next to, or inside, the client.
		add(filepath.Join(exeDir, "DofusArena"))
		add(filepath.Join(exeDir, "..", "game"))
	}

	// 3. Relative to the working directory, including the source checkout
	//    layout (running from server/, or from the repository root).
	add("data")
	// data-dist is the small subset committed to the repo so a source build
	// works the same way a downloaded release does, without needing the full
	// retail client just to run a fight.
	add("data-dist")
	add(filepath.Join("server", "data-dist"))
	add(filepath.Join("..", "client", "compiled", "game"))
	add(filepath.Join("client", "compiled", "game"))

	// 4. Where the retail client normally installs.
	for _, base := range installBases() {
		add(filepath.Join(base, "DofusArena"))
		add(filepath.Join(base, "Ankama", "DofusArena"))
	}
	return roots
}

// installBases returns the platform's usual application directories.
func installBases() []string {
	var bases []string
	addEnv := func(key string) {
		if v := os.Getenv(key); v != "" {
			bases = append(bases, v)
		}
	}
	switch runtime.GOOS {
	case "windows":
		addEnv("ProgramFiles")
		addEnv("ProgramFiles(x86)")
		addEnv("LOCALAPPDATA")
		addEnv("APPDATA")
		bases = append(bases, `C:\`)
	case "darwin":
		if home := os.Getenv("HOME"); home != "" {
			bases = append(bases, filepath.Join(home, "Applications"), home)
		}
		bases = append(bases, "/Applications")
	default:
		if home := os.Getenv("HOME"); home != "" {
			bases = append(bases, home, filepath.Join(home, "games"))
		}
		bases = append(bases, "/opt", "/usr/share/games", "/usr/local/games")
	}
	return bases
}

// SearchedPaths returns the locations Discover would look in, for an error
// message that tells the operator where to put the data (or which path to set)
// instead of leaving them guessing.
func SearchedPaths(configured string) []string {
	roots := candidateRoots(configured)
	out := make([]string, 0, len(roots))
	for _, r := range roots {
		if abs, err := filepath.Abs(r); err == nil {
			out = append(out, abs)
			continue
		}
		out = append(out, r)
	}
	return out
}
