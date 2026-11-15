// i18n.ts -- the studio's own UI translations: nav labels, headings, buttons,
// status. (The game's texts live in server/content; this only translates the
// tool's chrome.)
//
// t(key) returns the string for the current UI language, falling back to the
// English source if a key is missing in the target language. Keys are dotted
// (e.g. "nav.spells"). Interpolation: t("x", {n: 5}) replaces {n} in the string.

type Lang = "en" | "fr";

let current: Lang = "en";

// setUILang switches the active UI language ("en" | "fr"; unknown -> "en").
export function setUILang(code: string): void {
  current = code === "fr" ? "fr" : "en";
}

// t looks up a key in the current language table (English fallback), applying
// {placeholder} interpolation from vars.
export function t(key: string, vars?: Record<string, string | number>): string {
  const table = current === "fr" ? FR : EN;
  let s = table[key] ?? EN[key] ?? key;
  if (vars) {
    for (const [k, v] of Object.entries(vars)) {
      s = s.replace(new RegExp(`\\{${k}\\}`, "g"), String(v));
    }
  }
  return s;
}

// EN is the source table (also the fallback). FR overrides the ones that differ.
const EN: Record<string, string> = {
  // brand + shell
  "app.subtitle": "Content browser & card editor",
  "status.data.loaded": "content loaded",
  "status.data.missing": "content not loaded",
  "status.checkout": "reading the checkout's server/content",
  "status.embedded": "reading the embedded content (read-only)",

  // nav sections
  "section.Studio": "Studio",
  "section.Game Data": "Game Data",

  // nav items (keyed by nav id)
  "nav.overview": "Overview",
  "nav.spells": "Spells",
  "nav.cards": "Cards",
  "nav.summonings": "Summonings",
  "nav.staticEffects": "Static Effects",

  // overview
  "overview.hero.sub":
    "Browse the game's own content (server/content) — spells, cards, summonings, static effects — and edit the cards' balance.",
  "overview.jumpIn": "Jump in",
  "overview.jump.cards": "Coach and fighter cards, with the balance editor",
  "overview.stat.spells": "spells",
  "overview.stat.cards": "cards",
  "overview.stat.summonings": "summonings",
  "overview.stat.staticEffects": "static effects",
  "overview.sources": "Sources",
  "overview.sourcesHint":
    "Run from a checkout, the studio reads server/content, so it shows what the server loads. Anywhere else it shows the copy embedded in the binary.",
  "overview.cardsDir": "Cards (server/content/cards)",
  "overview.rulesDir": "Rules (server/content/rules)",
  "overview.embedded": "embedded in the studio",
  "overview.checkout": "checkout",
  "overview.readOnly": "embedded",
  "overview.preferences": "Preferences",
  "overview.prefLang": "Language of the studio's own interface.",
  "overview.language": "Language",

  // common table / actions
  "common.search": "Search {n} rows…",
  "common.export": "Export CSV",
  "common.save": "Save",
  "common.loading": "Loading…",
  "common.couldNotLoad": "Could not load {what}.",

  // cards view + editor
  "view.cards.count": "{coach} coach · {fighter} fighter · server/content",
  "cards.tabCoach": "Coach cards ({n})",
  "cards.tabFighter": "Fighter cards ({n})",
  "cards.source": "Editing server/content/cards ({dir}) · saved on Save",
  "cards.readOnly": "Read-only: the cards embedded in the studio (run it from a checkout to edit server/content/cards)",
  "cards.edit": "Edit",
  "cards.saved": "Saved",
  "cards.f.value": "Value",
  "cards.f.rank": "Rank (0–10)",
  "cards.f.price": "Price (currency:amount, …)",
  "cards.f.reqLevel": "Required level",
  "cards.f.inDraw": "In boosters",
  "cards.f.dropPercent": "Drop weight (0–100)",
  "cards.f.bound": "Bound (no trade)",
  "cards.f.undestructible": "Undestructible",
  "cards.f.apCost": "AP cost",
  "cards.f.rangeMin": "Range min",
  "cards.f.rangeMax": "Range max",
};

const FR: Record<string, string> = {
  // brand + shell
  "app.subtitle": "Explorateur de contenu et éditeur de cartes",
  "status.data.loaded": "contenu chargé",
  "status.data.missing": "contenu non chargé",
  "status.checkout": "lecture de server/content du dépôt",
  "status.embedded": "lecture du contenu intégré (lecture seule)",

  // nav sections
  "section.Studio": "Studio",
  "section.Game Data": "Données du jeu",

  // nav items
  "nav.overview": "Aperçu",
  "nav.spells": "Sorts",
  "nav.cards": "Cartes",
  "nav.summonings": "Invocations",
  "nav.staticEffects": "Effets statiques",

  // overview
  "overview.hero.sub":
    "Parcourez le contenu du jeu (server/content) — sorts, cartes, invocations, effets statiques — et équilibrez les cartes.",
  "overview.jumpIn": "Accès rapide",
  "overview.jump.cards": "Cartes de coach et de combattant, avec l’éditeur d’équilibrage",
  "overview.stat.spells": "sorts",
  "overview.stat.cards": "cartes",
  "overview.stat.summonings": "invocations",
  "overview.stat.staticEffects": "effets statiques",
  "overview.sources": "Sources",
  "overview.sourcesHint":
    "Lancé depuis un dépôt, le studio lit server/content, donc ce que charge le serveur. Ailleurs, il montre la copie intégrée au binaire.",
  "overview.cardsDir": "Cartes (server/content/cards)",
  "overview.rulesDir": "Règles (server/content/rules)",
  "overview.embedded": "intégré au studio",
  "overview.checkout": "dépôt",
  "overview.readOnly": "intégré",
  "overview.preferences": "Préférences",
  "overview.prefLang": "Langue de l’interface du studio.",
  "overview.language": "Langue",

  // common table / actions
  "common.search": "Rechercher dans {n} lignes…",
  "common.export": "Exporter CSV",
  "common.save": "Enregistrer",
  "common.loading": "Chargement…",
  "common.couldNotLoad": "Impossible de charger {what}.",

  // cards view + editor
  "view.cards.count": "{coach} coach · {fighter} combattant · server/content",
  "cards.tabCoach": "Cartes de coach ({n})",
  "cards.tabFighter": "Cartes de combattant ({n})",
  "cards.source": "Édition de server/content/cards ({dir}) · enregistré avec Enregistrer",
  "cards.readOnly":
    "Lecture seule : les cartes intégrées au studio (lancez-le depuis un dépôt pour éditer server/content/cards)",
  "cards.edit": "Modifier",
  "cards.saved": "Enregistré",
  "cards.f.value": "Valeur",
  "cards.f.rank": "Rang (0–10)",
  "cards.f.price": "Prix (monnaie:montant, …)",
  "cards.f.reqLevel": "Niveau requis",
  "cards.f.inDraw": "Dans les boosters",
  "cards.f.dropPercent": "Poids de tirage (0–100)",
  "cards.f.bound": "Liée (pas d’échange)",
  "cards.f.undestructible": "Indestructible",
  "cards.f.apCost": "Coût en PA",
  "cards.f.rangeMax": "Portée max",
  "cards.f.rangeMin": "Portée min",
};
