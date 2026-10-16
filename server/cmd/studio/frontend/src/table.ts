// A small, dependency-free sortable/filterable data-table with a detail
// drawer, faceted filters, keyboard navigation and CSV export. Used by every
// Phase 1 data view. Kept generic so each view only declares its columns,
// optional facets and an optional detail renderer.

import { t } from "./i18n";

export interface Column<T> {
  key: string;
  label: string;
  // value extracts the raw comparable/searchable value.
  value: (row: T) => string | number | boolean;
  // render optionally produces custom cell HTML (escaped by caller if needed).
  render?: (row: T) => string;
  align?: "left" | "right" | "center";
  width?: string;
}

// A Facet is an interactive filter shown in the table toolbar. Three kinds:
//   - "select": a dropdown of discrete values (auto-collected if options omitted)
//   - "toggle": a tri-state chip (any / yes / no) over a boolean predicate
//   - "range":  a numeric min/max pair
export interface Facet<T> {
  key: string;
  label: string;
  kind: "select" | "toggle" | "range";
  // value returns the row's value for this facet (string for select, boolean
  // for toggle, number for range).
  value: (row: T) => string | number | boolean;
  // options for a "select" facet; auto-derived from the data when omitted.
  options?: string[];
}

export interface TableOptions<T> {
  columns: Column<T>[];
  rows: T[];
  // detail renders the drawer body for a selected row (HTML string).
  detail?: (row: T) => string;
  // drawerTitle produces the drawer header text for a row (defaults to none).
  drawerTitle?: (row: T) => string;
  // searchText builds the haystack a row is matched against (defaults to
  // concatenating every column value).
  searchText?: (row: T) => string;
  emptyLabel?: string;
  // facets are optional interactive filters rendered under the search box.
  facets?: Facet<T>[];
  // exportName, when set, enables a CSV export button using this base filename.
  exportName?: string;
  // onDraw fires after every (re)render of the table body, so callers can
  // hydrate lazy content (e.g. icon cells) that the table re-creates on each
  // sort/filter/expand.
  onDraw?: (container: HTMLElement) => void;
}

function esc(v: unknown): string {
  return String(v).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c] as string);
}

export function boolBadge(b: boolean): string {
  return b ? `<span class="tb-badge on">yes</span>` : `<span class="tb-badge off">no</span>`;
}

type ToggleState = "any" | "yes" | "no";
interface RangeState {
  min: number | null;
  max: number | null;
}

// mountTable renders the table into container and wires all interactions.
export function mountTable<T>(container: HTMLElement, opts: TableOptions<T>) {
  let sortKey = opts.columns[0]?.key ?? "";
  let sortDir: 1 | -1 = 1;
  let query = "";
  let selected: number | null = null;
  let cursor = -1; // keyboard focus row (index into the filtered view)

  // Build the persistent shell once: a .tb-main region that the table redraws
  // into, plus a right-side overlay drawer (backdrop + panel) that survives
  // table redraws so its mounted editors aren't torn down on sort/filter.
  container.innerHTML = `
    <div class="tb-main"></div>
    <div class="tb-drawer-backdrop" hidden></div>
    <aside class="tb-drawer" hidden>
      <div class="tb-drawer-head">
        <span class="tb-drawer-title"></span>
        <button class="tb-drawer-close" title="Close (Esc)" aria-label="Close">\u00D7</button>
      </div>
      <div class="tb-drawer-body"></div>
    </aside>`;
  const mainEl = container.querySelector<HTMLElement>(".tb-main")!;
  const drawerEl = container.querySelector<HTMLElement>(".tb-drawer")!;
  const backdropEl = container.querySelector<HTMLElement>(".tb-drawer-backdrop")!;
  const drawerBody = drawerEl.querySelector<HTMLElement>(".tb-drawer-body")!;
  const drawerTitle = drawerEl.querySelector<HTMLElement>(".tb-drawer-title")!;

  function closeDrawer() {
    selected = null;
    drawerEl.hidden = true;
    backdropEl.hidden = true;
    drawerBody.innerHTML = "";
    // Reflect the de-selection in the table row highlight.
    mainEl.querySelectorAll(".tb-row.sel").forEach((r) => r.classList.remove("sel"));
  }

  const drawerTitleFor = opts.drawerTitle;

  // openDrawer fills and reveals the drawer for the row at absolute index `idx`,
  // then runs onDraw against the drawer body so its lazy editors mount there.
  function openDrawer(idx: number) {
    if (!opts.detail) return;
    const row = opts.rows[idx];
    if (!row) return;
    selected = idx;
    drawerTitle.textContent = drawerTitleFor?.(row) ?? "";
    drawerBody.innerHTML = opts.detail(row);
    drawerEl.hidden = false;
    backdropEl.hidden = false;
    drawerBody.scrollTop = 0;
    opts.onDraw?.(drawerBody);
    // Highlight the selected row without a full redraw.
    mainEl.querySelectorAll(".tb-row.sel").forEach((r) => r.classList.remove("sel"));
    mainEl.querySelector<HTMLElement>(`.tb-row[data-idx="${idx}"]`)?.classList.add("sel");
  }

  backdropEl.addEventListener("click", closeDrawer);
  drawerEl.querySelector<HTMLButtonElement>(".tb-drawer-close")!.addEventListener("click", closeDrawer);
  container.addEventListener("keydown", (ev) => {
    if (ev.key === "Escape" && !drawerEl.hidden) {
      ev.preventDefault();
      closeDrawer();
    }
  });

  const facets = opts.facets ?? [];
  const toggleStates = new Map<string, ToggleState>();
  const selectStates = new Map<string, string>();
  const rangeStates = new Map<string, RangeState>();
  for (const f of facets) {
    if (f.kind === "toggle") toggleStates.set(f.key, "any");
    if (f.kind === "select") selectStates.set(f.key, "");
    if (f.kind === "range") rangeStates.set(f.key, { min: null, max: null });
  }

  // Derive select-facet options from the data once.
  const facetOptions = new Map<string, string[]>();
  for (const f of facets) {
    if (f.kind !== "select") continue;
    if (f.options) {
      facetOptions.set(f.key, f.options);
      continue;
    }
    const set = new Set<string>();
    for (const row of opts.rows) set.add(String(f.value(row)));
    facetOptions.set(
      f.key,
      [...set].sort((a, b) => a.localeCompare(b, undefined, { numeric: true })),
    );
  }

  const search =
    opts.searchText ??
    ((row: T) =>
      opts.columns
        .map((c) => c.value(row))
        .join(" ")
        .toLowerCase());

  function facetPass(row: T): boolean {
    for (const f of facets) {
      if (f.kind === "toggle") {
        const st = toggleStates.get(f.key)!;
        if (st === "any") continue;
        const v = !!f.value(row);
        if (st === "yes" && !v) return false;
        if (st === "no" && v) return false;
      } else if (f.kind === "select") {
        const sel = selectStates.get(f.key)!;
        if (sel && String(f.value(row)) !== sel) return false;
      } else if (f.kind === "range") {
        const r = rangeStates.get(f.key)!;
        const v = Number(f.value(row));
        if (r.min != null && v < r.min) return false;
        if (r.max != null && v > r.max) return false;
      }
    }
    return true;
  }

  function activeFilterCount(): number {
    let n = query.trim() ? 1 : 0;
    for (const [, st] of toggleStates) if (st !== "any") n++;
    for (const [, sel] of selectStates) if (sel) n++;
    for (const [, r] of rangeStates) if (r.min != null || r.max != null) n++;
    return n;
  }

  function filtered(): { row: T; idx: number }[] {
    const q = query.trim().toLowerCase();
    let out = opts.rows.map((row, idx) => ({ row, idx }));
    if (q) out = out.filter(({ row }) => search(row).toLowerCase().includes(q));
    if (facets.length) out = out.filter(({ row }) => facetPass(row));
    const col = opts.columns.find((c) => c.key === sortKey);
    if (col) {
      out.sort((a, b) => {
        const va = col.value(a.row);
        const vb = col.value(b.row);
        if (va < vb) return -1 * sortDir;
        if (va > vb) return 1 * sortDir;
        return 0;
      });
    }
    return out;
  }

  function facetsHTML(): string {
    if (!facets.length) return "";
    const parts = facets.map((f) => {
      if (f.kind === "toggle") {
        const st = toggleStates.get(f.key)!;
        return `<button class="tb-facet-toggle ${st !== "any" ? "on " + st : ""}" data-facet-toggle="${esc(
          f.key,
        )}" title="${esc(f.label)}: click to cycle any / yes / no">
            <span class="tb-facet-label">${esc(f.label)}</span>
            <span class="tb-facet-state">${st === "any" ? "any" : st}</span>
          </button>`;
      }
      if (f.kind === "select") {
        const sel = selectStates.get(f.key)!;
        const optsHtml = [`<option value="">${esc(f.label)}: all</option>`]
          .concat(
            (facetOptions.get(f.key) ?? []).map(
              (o) => `<option value="${esc(o)}" ${o === sel ? "selected" : ""}>${esc(o)}</option>`,
            ),
          )
          .join("");
        return `<select class="tb-facet-select ${sel ? "on" : ""}" data-facet-select="${esc(
          f.key,
        )}">${optsHtml}</select>`;
      }
      // range
      const r = rangeStates.get(f.key)!;
      const on = r.min != null || r.max != null;
      const stepper = (bound: "min" | "max") => `
          <span class="tb-step" data-facet-range="${esc(f.key)}" data-bound="${bound}">
            <button type="button" class="tb-step-btn" data-step="-1" title="decrease">\u2212</button>
            <input type="number" class="tb-facet-${bound}" data-facet-range-${bound}="${esc(
              f.key,
            )}" placeholder="${bound}" value="${(bound === "min" ? r.min : r.max) ?? ""}" />
            <button type="button" class="tb-step-btn" data-step="1" title="increase">+</button>
          </span>`;
      return `<span class="tb-facet-range ${on ? "on" : ""}">
          <span class="tb-facet-label">${esc(f.label)}</span>
          ${stepper("min")}
          <span class="tb-facet-dash">\u2013</span>
          ${stepper("max")}
        </span>`;
    });
    const cleared = activeFilterCount() > 0;
    return `<div class="tb-facets">${parts.join("")}${
      cleared ? `<button class="tb-facet-clear" data-facet-clear>clear</button>` : ""
    }</div>`;
  }

  function toCSV(data: { row: T }[]): string {
    const headers = opts.columns.map((c) => c.label);
    const escCell = (v: unknown) => {
      const s = String(v ?? "");
      return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
    };
    const lines = [headers.map(escCell).join(",")];
    for (const { row } of data) {
      lines.push(opts.columns.map((c) => escCell(c.value(row))).join(","));
    }
    return lines.join("\r\n");
  }

  function draw() {
    const data = filtered();
    if (cursor >= data.length) cursor = data.length - 1;

    const head = opts.columns
      .map((c) => {
        const active = c.key === sortKey;
        const arrow = active ? (sortDir === 1 ? " \u25B2" : " \u25BC") : "";
        return `<th data-sort="${c.key}" style="text-align:${c.align ?? "left"};${
          c.width ? `width:${c.width};` : ""
        }" class="${active ? "sorted" : ""}">${esc(c.label)}${arrow}</th>`;
      })
      .join("");

    const body =
      data.length === 0
        ? `<tr><td colspan="${opts.columns.length}" class="tb-empty">
             <div class="tb-empty-inner"><span class="tb-empty-ico">\u2205</span>
             <span>${esc(opts.emptyLabel ?? "No matching rows")}</span>
             ${activeFilterCount() ? `<button class="tb-empty-clear" data-facet-clear>Clear filters</button>` : ""}
             </div></td></tr>`
        : data
            .map(({ row, idx }, viewIdx) => {
              const cells = opts.columns
                .map((c) => {
                  const content = c.render ? c.render(row) : esc(c.value(row));
                  return `<td style="text-align:${c.align ?? "left"}">${content}</td>`;
                })
                .join("");
              const isSel = selected === idx;
              const isCursor = viewIdx === cursor;
              // Detail now opens in a right-side drawer (see openDrawer); rows
              // no longer expand inline.
              return `<tr class="tb-row ${isSel ? "sel" : ""} ${
                isCursor ? "cursor" : ""
              }" data-idx="${idx}" data-view="${viewIdx}">${cells}</tr>`;
            })
            .join("");

    // Preserve the scroll position across the full re-render (clicking a row to
    // select it must NOT jump the list back to the top).
    const prevScroll = mainEl.querySelector<HTMLElement>(".tb-scroll")?.scrollTop ?? 0;

    mainEl.innerHTML = `
      <div class="tb-toolbar">
        <div class="tb-search-wrap">
          <span class="tb-search-ico">\u2315</span>
          <input class="tb-search" placeholder="${esc(t("common.search", { n: opts.rows.length }))}" value="${esc(
            query,
          )}" />
          ${query ? `<button class="tb-search-clear" data-search-clear title="Clear search">\u00D7</button>` : ""}
        </div>
        <span class="tb-count"><b>${data.length.toLocaleString()}</b> / ${opts.rows.length.toLocaleString()}</span>
        ${
          opts.exportName
            ? `<button class="tb-export" data-export title="Export the filtered rows as CSV">${esc(t("common.export"))}</button>`
            : ""
        }
      </div>
      ${facetsHTML()}
      <div class="tb-scroll" tabindex="0">
        <table class="tb">
          <thead><tr>${head}</tr></thead>
          <tbody>${body}</tbody>
        </table>
      </div>`;

    // Restore the scroll offset onto the freshly-rendered scroll region.
    const scrollEl = mainEl.querySelector<HTMLElement>(".tb-scroll");
    if (scrollEl) scrollEl.scrollTop = prevScroll;

    wire(data);
    // Hydrate any lazy content in the table body (icon cells etc.). The drawer
    // is hydrated separately in openDrawer so its editors survive table redraws.
    opts.onDraw?.(mainEl);
  }

  function wire(data: { row: T; idx: number }[]) {
    const input = container.querySelector<HTMLInputElement>(".tb-search")!;
    input.addEventListener("input", () => {
      query = input.value;
      const pos = input.selectionStart;
      draw();
      const ni = container.querySelector<HTMLInputElement>(".tb-search")!;
      ni.focus();
      if (pos != null) ni.setSelectionRange(pos, pos);
    });
    container.querySelector<HTMLButtonElement>("[data-search-clear]")?.addEventListener("click", () => {
      query = "";
      draw();
      container.querySelector<HTMLInputElement>(".tb-search")?.focus();
    });

    container.querySelectorAll<HTMLElement>("th[data-sort]").forEach((th) => {
      th.addEventListener("click", () => {
        const k = th.dataset.sort!;
        if (k === sortKey) sortDir = sortDir === 1 ? -1 : 1;
        else {
          sortKey = k;
          sortDir = 1;
        }
        draw();
      });
    });

    // Facet interactions.
    container.querySelectorAll<HTMLElement>("[data-facet-toggle]").forEach((el) => {
      el.addEventListener("click", () => {
        const k = el.dataset.facetToggle!;
        const cur = toggleStates.get(k)!;
        toggleStates.set(k, cur === "any" ? "yes" : cur === "yes" ? "no" : "any");
        draw();
      });
    });
    container.querySelectorAll<HTMLSelectElement>("[data-facet-select]").forEach((el) => {
      el.addEventListener("change", () => {
        selectStates.set(el.dataset.facetSelect!, el.value);
        draw();
      });
    });
    container.querySelectorAll<HTMLInputElement>("[data-facet-range-min]").forEach((el) => {
      el.addEventListener("input", () => {
        const r = rangeStates.get(el.dataset.facetRangeMin!)!;
        r.min = el.value === "" ? null : Number(el.value);
        const pos = el.selectionStart;
        draw();
        const ni = container.querySelector<HTMLInputElement>(`[data-facet-range-min="${el.dataset.facetRangeMin}"]`);
        ni?.focus();
        if (ni && pos != null) ni.setSelectionRange(pos, pos);
      });
    });
    container.querySelectorAll<HTMLInputElement>("[data-facet-range-max]").forEach((el) => {
      el.addEventListener("input", () => {
        const r = rangeStates.get(el.dataset.facetRangeMax!)!;
        r.max = el.value === "" ? null : Number(el.value);
        const pos = el.selectionStart;
        draw();
        const ni = container.querySelector<HTMLInputElement>(`[data-facet-range-max="${el.dataset.facetRangeMax}"]`);
        ni?.focus();
        if (ni && pos != null) ni.setSelectionRange(pos, pos);
      });
    });
    container.querySelectorAll<HTMLButtonElement>(".tb-step-btn").forEach((btn) => {
      btn.addEventListener("click", () => {
        const wrap = btn.closest<HTMLElement>(".tb-step")!;
        const key = wrap.dataset.facetRange!;
        const bound = wrap.dataset.bound as "min" | "max";
        const delta = Number(btn.dataset.step);
        const r = rangeStates.get(key)!;
        const cur = bound === "min" ? r.min : r.max;
        const next = (cur ?? 0) + delta;
        if (bound === "min") r.min = next;
        else r.max = next;
        draw();
      });
    });
    container.querySelectorAll<HTMLElement>("[data-facet-clear]").forEach((el) => {
      el.addEventListener("click", () => {
        query = "";
        for (const k of toggleStates.keys()) toggleStates.set(k, "any");
        for (const k of selectStates.keys()) selectStates.set(k, "");
        for (const k of rangeStates.keys()) rangeStates.set(k, { min: null, max: null });
        draw();
      });
    });

    container.querySelector<HTMLButtonElement>("[data-export]")?.addEventListener("click", () => {
      const csv = toCSV(data);
      const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `${opts.exportName}.csv`;
      a.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    });

    if (opts.detail) {
      mainEl.querySelectorAll<HTMLElement>(".tb-row").forEach((tr) => {
        tr.addEventListener("click", () => {
          const idx = Number(tr.dataset.idx);
          cursor = Number(tr.dataset.view);
          // Click the already-open row to close the drawer; otherwise open it.
          if (selected === idx) closeDrawer();
          else openDrawer(idx);
        });
      });
    }

    // Keyboard navigation on the scroll region.
    const scroll = container.querySelector<HTMLElement>(".tb-scroll")!;
    scroll.addEventListener("keydown", (ev) => {
      if (ev.key === "ArrowDown" || ev.key === "ArrowUp") {
        ev.preventDefault();
        cursor = Math.max(0, Math.min(data.length - 1, cursor + (ev.key === "ArrowDown" ? 1 : -1)));
        draw();
        container.querySelector<HTMLElement>(".tb-row.cursor")?.scrollIntoView({ block: "nearest" });
        container.querySelector<HTMLElement>(".tb-scroll")?.focus();
      } else if (ev.key === "Enter" && opts.detail && cursor >= 0 && cursor < data.length) {
        ev.preventDefault();
        const idx = data[cursor].idx;
        if (selected === idx) closeDrawer();
        else openDrawer(idx);
      }
    });
  }

  draw();
}
