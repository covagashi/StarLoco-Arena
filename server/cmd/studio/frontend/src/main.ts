import "./style.css";
import { getEnv, getPaths, getDataCounts, type Paths, type DataCounts } from "./backend";
import { viewSpells, viewCards, viewSummonings, viewStaticEffects } from "./views";
import { t, setUILang } from "./i18n";

// -------- App shell / navigation --------
// Sectioned sidebar, brand, status bar and overview over the content backend
// (server/content: the rules tables and the cards).

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
];

// UI-only language toggle (switches the studio's own chrome only).
const LANG_OPTIONS = [
  { code: "en", label: "English" },
  { code: "fr", label: "Fran\u00E7ais" },
];
let lang = "en";

let current = "overview";
let paths: Paths = { contentDir: "", rulesDir: "" };
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
      <div class="logo">PA</div>
      <div class="title"><b>Pippop Arena Studio</b><span>${esc(t("app.subtitle"))}</span></div>
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
  const dataOk = !!counts && !counts.error;
  const checkout = paths.contentDir !== "" && paths.rulesDir !== "";
  status.innerHTML = `
    <span><span class="dot ${dataOk ? "ok" : "err"}"></span>${t(dataOk ? "status.data.loaded" : "status.data.missing")}</span>
    <span><span class="dot ${checkout ? "ok" : "err"}"></span>${t(checkout ? "status.checkout" : "status.embedded")}</span>
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
  };
  dataViews[current]?.(main);
}

function overviewPage(): string {
  const cardsRow = pathRow(t("overview.cardsDir"), paths.contentDir);
  const rulesRow = pathRow(t("overview.rulesDir"), paths.rulesDir);

  const jump = (view: string, icon: string, title: string, desc: string) =>
    `<button class="ov-jump" data-nav-jump="${view}">
       <span class="ov-jump-ico">${icon}</span>
       <span class="ov-jump-t"><b>${esc(title)}</b><span>${esc(desc)}</span></span>
       <span class="ov-jump-arrow">\u2192</span>
     </button>`;

  return `
    <div class="ov-hero">
      <div class="ov-hero-badge">PA</div>
      <div>
        <h1 class="ov-hero-title">Pippop Arena Studio</h1>
        <p class="ov-hero-sub">${esc(t("overview.hero.sub"))}</p>
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
      ${jump("staticEffects", "\u2622", t("nav.staticEffects"), "Glyphs, traps and other static effects")}
    </div>

    <div class="card">
      <h2>${esc(t("overview.sources"))}</h2>
      <p class="hint">${esc(t("overview.sourcesHint"))}</p>
      ${cardsRow}
      ${rulesRow}
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

function pathRow(label: string, value: string): string {
  return `
    <div class="path-row">
      <div class="path-info">
        <div class="path-label">${esc(label)}</div>
        <div class="path-value ${value ? "" : "empty"}">${value ? esc(value) : esc(t("overview.embedded"))}</div>
      </div>
      <span class="pill ${value ? "ok" : "err"}">${value ? esc(t("overview.checkout")) : esc(t("overview.readOnly"))}</span>
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
  await refreshCounts();
}

boot();
