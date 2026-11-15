// backend.ts — a thin, typed bridge over the Wails-injected Go bindings.
//
// Wails exposes every exported method of the bound `App` struct at runtime as
// `window.go.main.App.<Method>()` returning a Promise. We type those calls here
// and provide a graceful fallback (empty data + a "not connected" flag) so the
// bundle still builds and can be previewed in a plain browser outside the Wails
// webview. Everything comes from the game's own content (server/content); the
// tables are read-only except the cards, which UpdateCoachCard /
// UpdateFighterCard save to server/content/cards.

export interface Paths {
  contentDir: string; // server/content/cards; "" = embedded, read-only
  rulesDir: string; // server/content/rules; "" = embedded
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
  reqLevel: number;
  inDraw: boolean;
  dropPercent: number;
  bound: boolean;
  undestructible: boolean;
}

// CoachCardEdit is the editable part of a coach card (Go: CoachCardEdit).
export interface CoachCardEdit {
  id: number;
  value: number;
  rank: number;
  price: string;
  reqLevel: number;
  inDraw: boolean;
  dropPercent: number;
  bound: boolean;
  undestructible: boolean;
}

// FighterCardEdit is the editable part of a fighter card (Go: FighterCardEdit).
export interface FighterCardEdit {
  id: number;
  value: number;
  apCost: number;
  rangeMin: number;
  rangeMax: number;
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
  apCost: number;
  rangeMin: number;
  rangeMax: number;
  usable: boolean;
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
  GetEnv(): Promise<Env>;
  GetDataCounts(): Promise<DataCounts>;
  GetSpells(): Promise<SpellDTO[]>;
  GetCoachCards(): Promise<CoachCardDTO[]>;
  GetFighterCards(): Promise<FighterCardDTO[]>;
  UpdateCoachCard(e: CoachCardEdit): Promise<void>;
  UpdateFighterCard(e: FighterCardEdit): Promise<void>;
  GetSummonings(): Promise<SummoningDTO[]>;
  GetStaticEffects(): Promise<StaticEffectDTO[]>;
}

// app resolves the runtime-injected bindings, or null when not inside Wails.
function app(): AppBindings | null {
  const w = window as unknown as { go?: { main?: { App?: AppBindings } } };
  return w.go?.main?.App ?? null;
}

const NO_PATHS: Paths = { contentDir: "", rulesDir: "" };
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

const NOT_CONNECTED = new Error("Not connected to the Studio backend.");

export function updateCoachCard(e: CoachCardEdit): Promise<void> {
  return app()?.UpdateCoachCard(e) ?? Promise.reject(NOT_CONNECTED);
}

export function updateFighterCard(e: FighterCardEdit): Promise<void> {
  return app()?.UpdateFighterCard(e) ?? Promise.reject(NOT_CONNECTED);
}

export function getSummonings(): Promise<SummoningDTO[]> {
  return app()?.GetSummonings() ?? Promise.resolve([]);
}

export function getStaticEffects(): Promise<StaticEffectDTO[]> {
  return app()?.GetStaticEffects() ?? Promise.resolve([]);
}
