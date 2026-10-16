import "./style.css";
import { getEnv, getPaths, setDataDir, setClientDir, getDataCounts, type Paths, type DataCounts } from "./backend";
import { viewSpells, viewCards, viewSummonings, viewStaticEffects } from "./views";
import { viewAssets } from "./assets";
import { viewSprites } from "./sprites";
import { viewMaps } from "./maps";
import { t, setUILang } from "./i18n";

// -------- App shell / navigation --------
// Reproduces the v2.04 studio design (sectioned sidebar, brand, status bar,
// overview hero) on the 2.70 read-only backend.

interface NavEntry {
  id: string;
  icon: string;
  section: string;
}

const NAV: NavEntry[] = [
  { id: "overview", icon: "\u25C8", section: "Studio" },
  { id: "spells", icon: "\u2726", section: "Game Data" },
  { id: "cards", icon: "\u2617", section: "Game Data" },
  { id: "summonings", icon: "\u269C", section: "Game Data" },
  { id: "staticEffects", icon: "\u2622", section: "Game Data" },
  { id: "assets", icon: "\u25A6", section: "Assets" },
  { id: "sprites", icon: "\u25A3", section: "Assets" },
  { id: "maps", icon: "\u25C6", section: "World" },
];

// UI-only language toggle (the 2.70 backend ships no i18n name tables, so this
// switches the studio's own chrome only).
const LANG_OPTIONS = [
  { code: "en", label: "English" },
  { code: "fr", label: "Fran\u00E7ais" },
];
let lang = "en";

let current = "overview";
let paths: Paths = { dataDir: "", clientDir: "", dataDirValid: false, clientDirValid: false };
let counts: DataCounts | null = null;

const app = document.querySelector<HTMLDivElement>("#app")!;

function esc(s: string): string {
  return s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c] as string);
}

function renderShell(): void {
  const sections = new Map<string, NavEntry[]>();
  for (const e of NAV) {
    if (!sections.has(e.section)) sections.set(e.section, []);
    sections.get(e.section)!.push(e);
  }

  let navHtml = `
    <div class="brand">
      <div class="logo">DA</div>
      <div class="title"><b>DofusArena Studio</b><span>2.70 \u00B7 ${esc(t("app.subtitle"))}</span></div>
    </div>
    <div class="nav-scroll">`;
  for (const [section, entries] of sections) {
    navHtml += `<div class="nav-section">${esc(t("section." + section))}</div>`;
    for (const e of entries) {
      navHtml += `
        <div class="nav-item ${e.id === current ? "active" : ""}" data-nav="${e.id}">
          <span class="ico">${e.icon}</span>
          <span>${esc(t("nav." + e.id))}</span>
          ${navBadge(e)}
        </div>`;
    }
  }
  navHtml += `</div>`;

  app.innerHTML = `
    <div class="nav">${navHtml}</div>
    <div class="main" id="main"></div>
    <div class="status" id="status"></div>`;

  app.querySelectorAll<HTMLElement>("[data-nav]").forEach((el) => {
    el.addEventListener("click", () => navigate(el.dataset.nav!));
  });

  renderStatus();
  renderPage();
}

// navBadge shows the live record count for data views (when loaded).
function navBadge(e: NavEntry): string {
  if (counts && !counts.error) {
    const map: Record<string, number> = {
      spells: counts.spells,
      cards: counts.coachCards + counts.fighterCards,
      summonings: counts.summonings,
      staticEffects: counts.staticEffects,
    };
    if (e.id in map) return `<span class="count">${map[e.id].toLocaleString()}</span>`;
  }
  return "";
}

function renderStatus(): void {
  const status = document.querySelector<HTMLDivElement>("#status");
  if (!status) return;
  const dataOk = paths.dataDirValid;
  const clientOk = paths.clientDirValid;
  status.innerHTML = `
    <span><span class="dot ${dataOk ? "ok" : "err"}"></span>${t(dataOk ? "status.data.loaded" : "status.data.missing")}</span>
    <span><span class="dot ${clientOk ? "ok" : "err"}"></span>${t(clientOk ? "status.client.detected" : "status.client.missing")}</span>
    <span class="spacer"></span>
    <span class="mono" id="envline"></span>`;
  getEnv().then((env) => {
    const el = document.querySelector("#envline");
    if (el) el.textContent = `${env.os} \u00B7 studio ${env.version}`;
  });
}

function navigate(id: string): void {
  if (id === current) return;
  current = id;
  app.querySelectorAll<HTMLElement>("[data-nav]").forEach((el) => {
    el.classList.toggle("active", el.dataset.nav === id);
  });
  renderPage();
}

// Keyboard nav: Alt+1..9 jumps to the Nth sidebar entry.
window.addEventListener("keydown", (e) => {
  if (e.altKey && e.key >= "1" && e.key <= "9") {
    const idx = Number(e.key) - 1;
    if (idx < NAV.length) {
      e.preventDefault();
      navigate(NAV[idx].id);
    }
  }
});

function renderPage(): void {
  const main = document.querySelector<HTMLDivElement>("#main");
  if (!main) return;

  if (current === "overview") {
    main.innerHTML = overviewPage();
    wireOverview();
    return;
  }

  const dataViews: Record<string, (c: HTMLElement) => void> = {
    spells: viewSpells,
    cards: viewCards,
    summonings: viewSummonings,
    staticEffects: viewStaticEffects,
    assets: viewAssets,
    sprites: viewSprites,
    maps: viewMaps,
  };
  dataViews[current]?.(main);
}

function overviewPage(): string {
  const dataRow = pathRow(t("overview.dataDir"), paths.dataDir, paths.dataDirValid, "data");
  const clientRow = pathRow(t("overview.clientDir"), paths.clientDir, paths.clientDirValid, "client");

  const jump = (view: string, icon: string, title: string, desc: string) =>
    `<button class="ov-jump" data-nav-jump="${view}">
       <span class="ov-jump-ico">${icon}</span>
       <span class="ov-jump-t"><b>${esc(title)}</b><span>${esc(desc)}</span></span>
       <span class="ov-jump-arrow">\u2192</span>
     </button>`;

  return `
    <div class="ov-hero">
      <div class="ov-hero-badge">DA</div>
      <div>
        <h1 class="ov-hero-title">DofusArena 2.70 Studio</h1>
        <p class="ov-hero-sub">Read-only workbench \u2014 browse the 2.70 client's spells, cards, summonings, static effects, sprites and jars.</p>
      </div>
    </div>

    <div class="ov-statband">
      ${overviewStat(counts?.spells, t("overview.stat.spells"))}
      ${overviewStat(counts ? counts.coachCards + counts.fighterCards : undefined, t("overview.stat.cards"))}
      ${overviewStat(counts?.summonings, t("overview.stat.summonings"))}
      ${overviewStat(counts?.staticEffects, t("overview.stat.staticEffects"))}
    </div>

    <div class="ov-section-title">${esc(t("overview.jumpIn"))}</div>
    <div class="ov-jumps">
      ${jump("spells", "\u2726", t("nav.spells"), "Every spell, sortable & filterable")}
      ${jump("cards", "\u2617", t("nav.cards"), t("overview.jump.cards"))}
      ${jump("summonings", "\u269C", t("nav.summonings"), "Summon creature stat sheets")}
      ${jump("sprites", "\u25A3", t("nav.sprites"), t("overview.jump.sprites"))}
      ${jump("maps", "\u25C6", t("nav.maps"), t("overview.jump.maps"))}
      ${jump("assets", "\u25A6", t("nav.assets"), t("overview.jump.assets"))}
    </div>

    <div class="card">
      <h2>${esc(t("overview.sources"))}</h2>
      <p class="hint">The studio auto-detects the repo's <code>server/data</code> and <code>client/compiled</code> folders. Override them here if needed.</p>
      ${dataRow}
      ${clientRow}
    </div>

    <div class="card">
      <h2>${esc(t("overview.preferences"))}</h2>
      <p class="hint">${esc(t("overview.prefLang"))}</p>
      <div class="pref-row">
        <div class="pref-label">${esc(t("overview.language"))}</div>
        <select id="langSelect" class="pref-select">
          ${LANG_OPTIONS.map(
            (o) => `<option value="${o.code}" ${o.code === lang ? "selected" : ""}>${esc(o.label)}</option>`,
          ).join("")}
        </select>
      </div>
    </div>`;
}

function overviewStat(n: number | undefined, label: string): string {
  const val = n == null ? "\u2014" : n.toLocaleString();
  return `<div class="stat"><div class="n">${val}</div><div class="l">${esc(label)}</div></div>`;
}

function pathRow(label: string, value: string, valid: boolean, kind: string): string {
  return `
    <div class="path-row">
      <div class="path-info">
        <div class="path-label">${esc(label)}</div>
        <div class="path-value ${value ? "" : "empty"}">${value ? esc(value) : esc(t("overview.notSet"))}</div>
      </div>
      <span class="pill ${valid ? "ok" : "err"}">${valid ? esc(t("overview.valid")) : esc(t("overview.missing"))}</span>
      <button data-pick="${kind}">${esc(t("overview.change"))}</button>
    </div>`;
}

function wireOverview(): void {
  document.querySelectorAll<HTMLElement>("[data-nav-jump]").forEach((btn) => {
    btn.addEventListener("click", () => navigate(btn.dataset.navJump!));
  });

  const langSel = document.querySelector<HTMLSelectElement>("#langSelect");
  langSel?.addEventListener("change", () => {
    lang = langSel.value;
    setUILang(lang);
    renderShell();
  });

  document.querySelectorAll<HTMLButtonElement>("[data-pick]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const kind = btn.dataset.pick!;
      const entered = window.prompt(
        `Enter the ${kind} directory path:`,
        kind === "data" ? paths.dataDir : paths.clientDir,
      );
      if (entered == null) return;
      paths = kind === "data" ? await setDataDir(entered) : await setClientDir(entered);
      if (kind === "data") await refreshCounts();
      renderStatus();
      renderPage();
    });
  });
}

async function refreshCounts(): Promise<void> {
  try {
    counts = await getDataCounts();
  } catch {
    counts = null;
  }
  if (document.querySelector(".nav")) renderShell();
}

// -------- boot --------
async function boot(): Promise<void> {
  paths = await getPaths();
  renderShell();
  if (paths.dataDirValid) await refreshCounts();
}

boot();
