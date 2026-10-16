// Read-only game-data views for the 2.70 studio. Each reproduces the v2.04
// design: a page head + the shared faceted, sortable, CSV-exporting table
// (table.ts) with a right-side detail drawer. Data comes from the read-only
// v2.70 backend DTOs; there are no editors.

import { mountTable, boolBadge, type Column, type Facet } from "./table";
import { t } from "./i18n";
import {
  getSpells,
  getCoachCards,
  getFighterCards,
  getSummonings,
  getStaticEffects,
  type SpellDTO,
  type CoachCardDTO,
  type FighterCardDTO,
  type SummoningDTO,
  type StaticEffectDTO,
} from "./backend";

function esc(v: unknown): string {
  return String(v).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c] as string);
}

function pageHead(title: string, sub: string): string {
  return `<div class="page-head"><h1>${esc(title)}</h1><span class="sub">${esc(sub)}</span></div>`;
}

// recDetail renders a record's fields as a clean key/value list for the drawer.
function recDetail(rows: Array<[string, string]>): string {
  return (
    `<div class="rec-detail">` +
    rows
      .map(
        ([k, v]) =>
          `<div class="rec-row"><span class="rec-k">${esc(k)}</span><span class="rec-v">${esc(v)}</span></div>`,
      )
      .join("") +
    `</div>`
  );
}

function showError(container: HTMLElement, title: string, err: unknown): void {
  container.innerHTML =
    pageHead(title, "") +
    `<div class="placeholder"><div class="big">\u26A0</div>
       <div>${esc(t("common.couldNotLoad", { what: title.toLowerCase() }))}</div>
       <div class="mono" style="margin-top:6px;font-size:12.5px">${esc((err as Error).message)}</div>
     </div>`;
}

function yn(b: boolean): string {
  return b ? "yes" : "no";
}

// --- Spells -----------------------------------------------------------------

export function viewSpells(container: HTMLElement): void {
  container.innerHTML =
    pageHead(t("nav.spells"), t("common.loading")) + `<div class="loading">${t("common.loading")}</div>`;
  getSpells()
    .then((rows) => {
      container.innerHTML =
        pageHead(t("nav.spells"), `${rows.length} spells \u00B7 data.bdat`) + `<div class="view-body"></div>`;
      const host = container.querySelector<HTMLElement>(".view-body")!;
      const columns: Column<SpellDTO>[] = [
        { key: "id", label: "ID", align: "right", width: "64px", value: (r) => r.id },
        { key: "breedId", label: "Breed", align: "right", value: (r) => r.breedId },
        { key: "ap", label: "AP", align: "right", value: (r) => r.ap },
        { key: "range", label: "Range", value: (r) => r.rangeMin, render: (r) => `${r.rangeMin}\u2013${r.rangeMax}` },
        { key: "value", label: "Value", align: "right", value: (r) => r.value },
        { key: "scriptId", label: "Script", align: "right", value: (r) => r.scriptId },
        { key: "testLoS", label: "LoS", align: "center", value: (r) => r.testLoS, render: (r) => boolBadge(r.testLoS) },
        {
          key: "onlyLine",
          label: "Line",
          align: "center",
          value: (r) => r.onlyLine,
          render: (r) => boolBadge(r.onlyLine),
        },
        {
          key: "needFreeCell",
          label: "Free",
          align: "center",
          value: (r) => r.needFreeCell,
          render: (r) => boolBadge(r.needFreeCell),
        },
        { key: "effects", label: "Fx", align: "right", value: (r) => r.effects },
      ];
      const facets: Facet<SpellDTO>[] = [
        { key: "breedId", label: "Breed", kind: "select", value: (r) => String(r.breedId) },
        { key: "ap", label: "AP", kind: "range", value: (r) => r.ap },
        { key: "testLoS", label: "LoS", kind: "toggle", value: (r) => r.testLoS },
        { key: "onlyLine", label: "Line only", kind: "toggle", value: (r) => r.onlyLine },
      ];
      mountTable<SpellDTO>(host, {
        rows,
        columns,
        facets,
        exportName: "spells",
        drawerTitle: (r) => `Spell #${r.id}`,
        detail: (r) =>
          recDetail([
            ["ID", String(r.id)],
            ["Breed", String(r.breedId)],
            ["AP cost", String(r.ap)],
            ["Range", `${r.rangeMin}\u2013${r.rangeMax}`],
            ["Value (budget)", String(r.value)],
            ["Script ID", String(r.scriptId)],
            ["Test LoS", yn(r.testLoS)],
            ["Only line", yn(r.onlyLine)],
            ["Needs free cell", yn(r.needFreeCell)],
            ["Effects", String(r.effects)],
          ]),
      });
    })
    .catch((err) => showError(container, t("nav.spells"), err));
}

// --- Cards (coach + fighter sub-tabs) ---------------------------------------

export function viewCards(container: HTMLElement): void {
  container.innerHTML =
    pageHead(t("nav.cards"), t("common.loading")) + `<div class="loading">${t("common.loading")}</div>`;
  Promise.all([getCoachCards(), getFighterCards()])
    .then(([coach, fighter]) => {
      let tab: "coach" | "fighter" = "coach";
      const render = (): void => {
        container.innerHTML =
          pageHead(t("nav.cards"), t("view.cards.count", { coach: coach.length, fighter: fighter.length })) +
          `<div class="asset-chip-row cards-tabs">
             <button class="asset-chip ${tab === "coach" ? "on" : ""}" data-tab="coach">${esc(t("cards.tabCoach", { n: coach.length }))}</button>
             <button class="asset-chip ${tab === "fighter" ? "on" : ""}" data-tab="fighter">${esc(t("cards.tabFighter", { n: fighter.length }))}</button>
           </div>
           <div class="view-body"></div>`;
        container.querySelectorAll<HTMLElement>("[data-tab]").forEach((b) =>
          b.addEventListener("click", () => {
            tab = b.dataset.tab as "coach" | "fighter";
            render();
          }),
        );
        const host = container.querySelector<HTMLElement>(".view-body")!;
        if (tab === "coach") mountCoach(host, coach);
        else mountFighter(host, fighter);
      };
      render();
    })
    .catch((err) => showError(container, t("nav.cards"), err));
}

function mountCoach(host: HTMLElement, rows: CoachCardDTO[]): void {
  mountTable<CoachCardDTO>(host, {
    rows,
    exportName: "coach-cards",
    columns: [
      { key: "id", label: "ID", align: "right", width: "64px", value: (r) => r.id },
      { key: "iconRef", label: "Icon", align: "right", value: (r) => r.iconRef },
      { key: "cardSet", label: "Set", align: "right", value: (r) => r.cardSet },
      { key: "value", label: "Value", align: "right", value: (r) => r.value },
      { key: "rank", label: "Rank", align: "right", value: (r) => r.rank },
      { key: "price", label: "Price", value: (r) => r.price },
      {
        key: "purchasable",
        label: "Buy",
        align: "center",
        value: (r) => r.purchasable,
        render: (r) => boolBadge(r.purchasable),
      },
    ],
    facets: [
      { key: "cardSet", label: "Set", kind: "select", value: (r) => String(r.cardSet) },
      { key: "purchasable", label: "Purchasable", kind: "toggle", value: (r) => r.purchasable },
    ],
    drawerTitle: (r) => `Coach card #${r.id}`,
    detail: (r) =>
      recDetail([
        ["ID", String(r.id)],
        ["Icon ref", String(r.iconRef)],
        ["Card set", String(r.cardSet)],
        ["Value", String(r.value)],
        ["Rank", String(r.rank)],
        ["Price", r.price || "\u2014"],
        ["Purchasable", yn(r.purchasable)],
      ]),
  });
}

function mountFighter(host: HTMLElement, rows: FighterCardDTO[]): void {
  mountTable<FighterCardDTO>(host, {
    rows,
    exportName: "fighter-cards",
    columns: [
      { key: "id", label: "ID", align: "right", width: "64px", value: (r) => r.id },
      { key: "type", label: "Type", align: "right", value: (r) => r.type },
      { key: "value", label: "Value", align: "right", value: (r) => r.value },
      { key: "bonusHP", label: "HP", align: "right", value: (r) => r.bonusHP },
      { key: "bonusAP", label: "AP", align: "right", value: (r) => r.bonusAP },
      { key: "bonusMP", label: "MP", align: "right", value: (r) => r.bonusMP },
      { key: "bonusInit", label: "Init", align: "right", value: (r) => r.bonusInit },
      { key: "bonusRange", label: "Range", align: "right", value: (r) => r.bonusRange },
      { key: "equipEffects", label: "Equip fx", align: "right", value: (r) => r.equipEffects },
    ],
    facets: [{ key: "type", label: "Type", kind: "select", value: (r) => String(r.type) }],
    drawerTitle: (r) => `Fighter card #${r.id}`,
    detail: (r) =>
      recDetail([
        ["ID", String(r.id)],
        ["Type", String(r.type)],
        ["Value", String(r.value)],
        ["Bonus HP", String(r.bonusHP)],
        ["Bonus AP", String(r.bonusAP)],
        ["Bonus MP", String(r.bonusMP)],
        ["Bonus Init", String(r.bonusInit)],
        ["Bonus Range", String(r.bonusRange)],
        ["Equip effects", String(r.equipEffects)],
      ]),
  });
}

// --- Summonings -------------------------------------------------------------

export function viewSummonings(container: HTMLElement): void {
  container.innerHTML =
    pageHead(t("nav.summonings"), t("common.loading")) + `<div class="loading">${t("common.loading")}</div>`;
  getSummonings()
    .then((rows) => {
      container.innerHTML =
        pageHead(t("nav.summonings"), `${rows.length} summonings \u00B7 data.bdat`) + `<div class="view-body"></div>`;
      const host = container.querySelector<HTMLElement>(".view-body")!;
      mountTable<SummoningDTO>(host, {
        rows,
        exportName: "summonings",
        columns: [
          { key: "id", label: "ID", align: "right", width: "64px", value: (r) => r.id },
          { key: "hp", label: "HP", align: "right", value: (r) => r.hp },
          { key: "ap", label: "AP", align: "right", value: (r) => r.ap },
          { key: "mp", label: "MP", align: "right", value: (r) => r.mp },
          { key: "look", label: "Look", align: "right", value: (r) => r.look },
          { key: "primarySpell", label: "Spell", align: "right", value: (r) => r.primarySpell },
          { key: "spells", label: "Spells", value: (r) => r.spells },
        ],
        facets: [
          { key: "hp", label: "HP", kind: "range", value: (r) => r.hp },
          { key: "ap", label: "AP", kind: "range", value: (r) => r.ap },
        ],
        drawerTitle: (r) => `Summoning #${r.id}`,
        detail: (r) =>
          recDetail([
            ["ID", String(r.id)],
            ["HP", String(r.hp)],
            ["AP", String(r.ap)],
            ["MP", String(r.mp)],
            ["Look / gfx", String(r.look)],
            ["Primary spell", String(r.primarySpell)],
            ["Spells", r.spells || "\u2014"],
          ]),
      });
    })
    .catch((err) => showError(container, t("nav.summonings"), err));
}

// --- Static Effects ---------------------------------------------------------

export function viewStaticEffects(container: HTMLElement): void {
  container.innerHTML =
    pageHead(t("nav.staticEffects"), t("common.loading")) + `<div class="loading">${t("common.loading")}</div>`;
  getStaticEffects()
    .then((rows) => {
      container.innerHTML =
        pageHead(t("nav.staticEffects"), `${rows.length} traps / glyphs \u00B7 data.bdat`) +
        `<div class="view-body"></div>`;
      const host = container.querySelector<HTMLElement>(".view-body")!;
      mountTable<StaticEffectDTO>(host, {
        rows,
        exportName: "static-effects",
        columns: [
          { key: "id", label: "ID", align: "right", width: "64px", value: (r) => r.id },
          { key: "type", label: "Type", value: (r) => r.type },
          { key: "label", label: "Label", value: (r) => r.label },
          { key: "areaShape", label: "Shape", align: "right", value: (r) => r.areaShape },
          { key: "maxExec", label: "Max exec", align: "right", value: (r) => r.maxExec },
          {
            key: "unlimited",
            label: "Unltd",
            align: "center",
            value: (r) => r.unlimited,
            render: (r) => boolBadge(r.unlimited),
          },
          { key: "appCondition", label: "Cond", align: "right", value: (r) => r.appCondition },
          { key: "effects", label: "Fx", align: "right", value: (r) => r.effects },
        ],
        facets: [
          { key: "type", label: "Type", kind: "select", value: (r) => r.type },
          { key: "unlimited", label: "Unlimited", kind: "toggle", value: (r) => r.unlimited },
        ],
        drawerTitle: (r) => `Static effect #${r.id}`,
        detail: (r) =>
          recDetail([
            ["ID", String(r.id)],
            ["Type", r.type || "\u2014"],
            ["Label", r.label || "\u2014"],
            ["Area shape", String(r.areaShape)],
            ["Max exec", String(r.maxExec)],
            ["Unlimited", yn(r.unlimited)],
            ["Application cond.", String(r.appCondition)],
            ["Triggers", r.appTriggers || "\u2014"],
            ["Effects", String(r.effects)],
          ]),
      });
    })
    .catch((err) => showError(container, t("nav.staticEffects"), err));
}
