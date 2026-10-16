// backend.ts — a thin, typed bridge over the Wails-injected Go bindings.
//
// Wails exposes every exported method of the bound `App` struct at runtime as
// `window.go.main.App.<Method>()` returning a Promise. We type those calls here
// and provide a graceful fallback (empty data + a "not connected" flag) so the
// bundle still builds and can be previewed in a plain browser outside the Wails
// webview. The 2.70 Studio is READ-ONLY: there are no setters beyond the data
// directory picker.

export interface Paths {
  dataDir: string;
  dataDirValid: boolean;
  clientDir: string;
  clientDirValid: boolean;
}

export interface JarInfo {
  name: string;
  entryCount: number;
  sizeBytes: number;
  error: string;
}

export interface AssetEntry {
  path: string;
  name: string;
  ext: string;
  size: number;
  kind: string; // "image" | "text" | "binary"
}

export interface AssetPreview {
  path: string;
  kind: string;
  mime: string;
  dataUrl: string;
  text: string;
  truncated: boolean;
  size: number;
  width: number;
  height: number;
}

export interface SpriteInfo {
  id: number;
  path: string;
  name: string;
  bytes: number;
}

export interface SpriteImage {
  path: string;
  width: number;
  height: number;
  dataUrl: string;
}

export interface SpriteExportResult {
  dir: string;
  total: number;
  written: number;
  failed: number;
  cancelled: boolean;
  elapsedMs: number;
}

export interface MapInfo {
  id: number;
  tiles: number;
  isArena: boolean;
}

interface MapCell {
  x: number;
  y: number;
  alt: number;
  w: boolean; // walkable floor vs obstacle block
}

export interface MapSpawn {
  x: number;
  y: number;
  z: number;
}

interface MapDrawable {
  gfxId: number;
  cellX: number;
  cellY: number;
  alt: number;
  abaH: number;
  originX: number;
  originY: number;
  w: number;
  h: number;
  flip: boolean;
}

interface MapGfx {
  drawables: MapDrawable[];
  truncated: boolean;
  error: string;
}

interface MapSprite {
  gfxId: number;
  dataUrl: string;
  w: number;
  h: number;
}

interface MapRender {
  dataUrl: string;
  worldX: number;
  worldY: number;
  worldW: number;
  worldH: number;
  empty: boolean;
  error: string;
}

export interface MapBounds {
  worldX: number;
  worldY: number;
  worldW: number;
  worldH: number;
  empty: boolean;
  error: string;
}

export interface MapView {
  dataUrl: string;
  worldX: number;
  worldY: number;
  worldW: number;
  worldH: number;
  empty: boolean;
  error: string;
}

export interface MapData {
  worldId: number;
  isArena: boolean;
  minX: number;
  minY: number;
  maxX: number;
  maxY: number;
  cellWidth: number;
  cellHeight: number;
  elevationUnit: number;
  cells: MapCell[];
  team0: MapSpawn[];
  team1: MapSpawn[];
  coach: MapSpawn[];
  truncated: boolean;
  error: string;
}

export interface Env {
  version: string;
  os: string;
}

export interface DataCounts {
  spells: number;
  coachCards: number;
  fighterCards: number;
  summonings: number;
  staticEffects: number;
  error: string;
}

export interface SpellDTO {
  id: number;
  breedId: number;
  value: number;
  scriptId: number;
  ap: number;
  rangeMin: number;
  rangeMax: number;
  testLoS: boolean;
  onlyLine: boolean;
  needFreeCell: boolean;
  effects: number;
}

export interface CoachCardDTO {
  id: number;
  iconRef: number;
  cardSet: number;
  value: number;
  rank: number;
  price: string;
  purchasable: boolean;
}

export interface FighterCardDTO {
  id: number;
  type: number;
  value: number;
  bonusHP: number;
  bonusAP: number;
  bonusMP: number;
  bonusInit: number;
  bonusRange: number;
  equipEffects: number;
}

export interface SummoningDTO {
  id: number;
  hp: number;
  ap: number;
  mp: number;
  look: number;
  primarySpell: number;
  spells: string;
}

export interface StaticEffectDTO {
  id: number;
  type: string;
  label: string;
  areaShape: number;
  maxExec: number;
  unlimited: boolean;
  appCondition: number;
  appTriggers: string;
  effects: number;
}

// AppBindings mirrors the exported methods of the Go App struct.
interface AppBindings {
  GetPaths(): Promise<Paths>;
  SetDataDir(dir: string): Promise<Paths>;
  SetClientDir(dir: string): Promise<Paths>;
  GetEnv(): Promise<Env>;
  GetDataCounts(): Promise<DataCounts>;
  GetSpells(): Promise<SpellDTO[]>;
  GetCoachCards(): Promise<CoachCardDTO[]>;
  GetFighterCards(): Promise<FighterCardDTO[]>;
  GetSummonings(): Promise<SummoningDTO[]>;
  GetStaticEffects(): Promise<StaticEffectDTO[]>;
  ListJars(): Promise<JarInfo[]>;
  ListJarEntries(jar: string): Promise<AssetEntry[]>;
  PreviewEntry(jar: string, entryPath: string): Promise<AssetPreview>;
  ListSprites(): Promise<SpriteInfo[]>;
  GetSprite(entryPath: string): Promise<SpriteImage>;
  ExportAllSprites(): Promise<SpriteExportResult>;
  ListMaps(): Promise<MapInfo[]>;
  GetMap(id: number): Promise<MapData>;
  GetMapGfx(id: number): Promise<MapGfx>;
  GetMapSprites(ids: number[]): Promise<MapSprite[]>;
  GetMapRender(id: number): Promise<MapRender>;
  GetMapBounds(id: number): Promise<MapBounds>;
  GetMapView(id: number, wl: number, wt: number, wr: number, wb: number, outW: number, outH: number): Promise<MapView>;
}

// app resolves the runtime-injected bindings, or null when not inside Wails.
function app(): AppBindings | null {
  const w = window as unknown as { go?: { main?: { App?: AppBindings } } };
  return w.go?.main?.App ?? null;
}

const NO_PATHS: Paths = { dataDir: "", dataDirValid: false, clientDir: "", clientDirValid: false };
const NO_ENV: Env = { version: "dev", os: "browser" };
const NO_COUNTS: DataCounts = {
  spells: 0,
  coachCards: 0,
  fighterCards: 0,
  summonings: 0,
  staticEffects: 0,
  error: "Not connected to the Studio backend (open via `wails dev` / the built app).",
};

export function getPaths(): Promise<Paths> {
  return app()?.GetPaths() ?? Promise.resolve(NO_PATHS);
}

export function setDataDir(dir: string): Promise<Paths> {
  return app()?.SetDataDir(dir) ?? Promise.resolve(NO_PATHS);
}

export function getEnv(): Promise<Env> {
  return app()?.GetEnv() ?? Promise.resolve(NO_ENV);
}

export function getDataCounts(): Promise<DataCounts> {
  return app()?.GetDataCounts() ?? Promise.resolve(NO_COUNTS);
}

export function getSpells(): Promise<SpellDTO[]> {
  return app()?.GetSpells() ?? Promise.resolve([]);
}

export function getCoachCards(): Promise<CoachCardDTO[]> {
  return app()?.GetCoachCards() ?? Promise.resolve([]);
}

export function getFighterCards(): Promise<FighterCardDTO[]> {
  return app()?.GetFighterCards() ?? Promise.resolve([]);
}

export function getSummonings(): Promise<SummoningDTO[]> {
  return app()?.GetSummonings() ?? Promise.resolve([]);
}

export function getStaticEffects(): Promise<StaticEffectDTO[]> {
  return app()?.GetStaticEffects() ?? Promise.resolve([]);
}

export function setClientDir(dir: string): Promise<Paths> {
  return app()?.SetClientDir(dir) ?? Promise.resolve(NO_PATHS);
}

export function listJars(): Promise<JarInfo[]> {
  return app()?.ListJars() ?? Promise.resolve([]);
}

export function listJarEntries(jar: string): Promise<AssetEntry[]> {
  return app()?.ListJarEntries(jar) ?? Promise.resolve([]);
}

export function previewEntry(jar: string, entryPath: string): Promise<AssetPreview> {
  return (
    app()?.PreviewEntry(jar, entryPath) ??
    Promise.resolve({
      path: entryPath,
      kind: "binary",
      mime: "",
      dataUrl: "",
      text: "",
      truncated: false,
      size: 0,
      width: 0,
      height: 0,
    })
  );
}

export function listSprites(): Promise<SpriteInfo[]> {
  return app()?.ListSprites() ?? Promise.resolve([]);
}

export function getSprite(entryPath: string): Promise<SpriteImage> {
  return app()?.GetSprite(entryPath) ?? Promise.resolve({ path: entryPath, width: 0, height: 0, dataUrl: "" });
}

export function exportAllSprites(): Promise<SpriteExportResult> {
  return (
    app()?.ExportAllSprites() ??
    Promise.resolve({ dir: "", total: 0, written: 0, failed: 0, cancelled: true, elapsedMs: 0 })
  );
}

// onEvent subscribes to a Wails runtime event (e.g. export progress); returns an
// unsubscribe function. No-op outside the Wails webview.
export function onEvent(name: string, cb: (data: unknown) => void): () => void {
  const w = window as unknown as {
    runtime?: {
      EventsOn?: (n: string, cb: (d: unknown) => void) => void;
      EventsOff?: (n: string) => void;
    };
  };
  if (w.runtime?.EventsOn) {
    w.runtime.EventsOn(name, cb);
    return () => w.runtime?.EventsOff?.(name);
  }
  return () => {};
}

export function listMaps(): Promise<MapInfo[]> {
  return app()?.ListMaps() ?? Promise.resolve([]);
}

export function getMapBounds(id: number): Promise<MapBounds> {
  return (
    app()?.GetMapBounds(id) ??
    Promise.resolve({ worldX: 0, worldY: 0, worldW: 0, worldH: 0, empty: true, error: "not connected" })
  );
}

export function getMapView(
  id: number,
  wl: number,
  wt: number,
  wr: number,
  wb: number,
  outW: number,
  outH: number,
): Promise<MapView> {
  return (
    app()?.GetMapView(id, wl, wt, wr, wb, outW, outH) ??
    Promise.resolve({ dataUrl: "", worldX: 0, worldY: 0, worldW: 0, worldH: 0, empty: true, error: "not connected" })
  );
}

export function getMap(id: number): Promise<MapData> {
  return (
    app()?.GetMap(id) ??
    Promise.resolve({
      worldId: id,
      isArena: false,
      minX: 0,
      minY: 0,
      maxX: 0,
      maxY: 0,
      cellWidth: 86,
      cellHeight: 43,
      elevationUnit: 10,
      cells: [],
      team0: [],
      team1: [],
      coach: [],
      truncated: false,
      error: "not connected",
    })
  );
}
