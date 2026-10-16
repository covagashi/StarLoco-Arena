// Isometric map viewer for the 2.70 worlds/arenas. Decodes come from the Go
// backend (topology tiles + .fmd placement cells); this renders them on a 2D
// canvas with the client's own projection (cellWidth 86, cellHeight 43,
// elevation 10): raised altitude blocks, a walkable/obstacle overlay, and — for
// fight arenas — team start cells and coach pedestals. Pan (drag), zoom (wheel /
// slider), hover to inspect a cell.

import { listMaps, getMap, getMapBounds, getMapView, type MapInfo, type MapData, type MapSpawn } from "./backend";
import { t } from "./i18n";

function esc(v: unknown): string {
  return String(v).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c] as string);
}

interface View {
  zoom: number;
  panX: number;
  panY: number;
  grid: boolean;
  walk: boolean; // highlight obstacle (non-walkable) cells
  spawns: boolean;
  art: boolean; // decorative gfx sprite layer
  topo: boolean; // altitude blocks (analytical)
}

// withTimeout resolves to "timeout" if p doesn't settle within ms, so a stuck
// backend call or image load can never hang the viewer forever.
function withTimeout<T>(p: Promise<T>, ms: number): Promise<T | "timeout"> {
  return Promise.race([p, new Promise<"timeout">((res) => setTimeout(() => res("timeout"), ms))]);
}

export function viewMaps(container: HTMLElement): void {
  container.innerHTML = `
    <div class="page-head"><h1>${esc(t("nav.maps"))}</h1><span class="sub">isometric viewer \u00B7 topology + spawns</span></div>
    <div class="map-toolbar">
      <select id="mapPick" class="map-pick"></select>
      <span class="map-badges" id="mapBadges"></span>
      <span class="tb-sep"></span>
      <label class="map-toggle"><input type="checkbox" id="tgArt" checked /> art</label>
      <label class="map-toggle"><input type="checkbox" id="tgTopo" /> topology</label>
      <label class="map-toggle"><input type="checkbox" id="tgWalk" checked /> obstacles</label>
      <label class="map-toggle"><input type="checkbox" id="tgSpawns" checked /> spawns</label>
      <label class="map-toggle"><input type="checkbox" id="tgGrid" /> grid</label>
      <span class="tb-sep"></span>
      <label class="sprite-zoom"><span>zoom</span><input type="range" id="mapZoom" min="0.2" max="3" step="0.05" value="1" /></label>
      <button id="mapReset" class="mini">Reset view</button>
    </div>
    <div class="map-stage" id="mapStage">
      <canvas id="mapCanvas"></canvas>
      <div class="map-readout" id="mapReadout"></div>
      <div class="map-legend" id="mapLegend"></div>
    </div>`;

  const pick = container.querySelector<HTMLSelectElement>("#mapPick")!;
  const badges = container.querySelector<HTMLElement>("#mapBadges")!;
  const stage = container.querySelector<HTMLElement>("#mapStage")!;
  const canvas = container.querySelector<HTMLCanvasElement>("#mapCanvas")!;
  const readout = container.querySelector<HTMLElement>("#mapReadout")!;
  const legend = container.querySelector<HTMLElement>("#mapLegend")!;
  const zoomInput = container.querySelector<HTMLInputElement>("#mapZoom")!;
  const ctx = canvas.getContext("2d")!;

  const view: View = { zoom: 1, panX: 0, panY: 0, grid: false, walk: true, spawns: true, art: true, topo: false };
  let dto: MapData | null = null;
  let minAlt = 0;
  let maxAlt = 0;
  let hover: { x: number; y: number; alt: number; w: boolean } | null = null;
  let artImg: HTMLImageElement | null = null;
  let artRWX = 0; // world rectangle the current art image covers
  let artRWY = 0;
  let artRWW = 0;
  let artRWH = 0;
  let artReady = false;
  let bounds: Awaited<ReturnType<typeof getMapBounds>> | null = null;
  let curId = -1;
  let loadToken = 0;
  let renderToken = 0;
  let renderTimer: number | null = null;

  // --- projection (world units; screen = world*zoom + pan) ---
  const HX = () => dto!.cellWidth / 2; // 43
  const HY = () => dto!.cellHeight / 2; // 21.5
  const EL = () => dto!.elevationUnit; // 10
  function projX(x: number, y: number): number {
    return (x - y) * HX();
  }
  function projY(x: number, y: number, alt: number): number {
    return (x + y) * HY() - alt * EL();
  }

  function resizeCanvas(): void {
    const r = stage.getBoundingClientRect();
    canvas.width = Math.max(320, Math.floor(r.width));
    canvas.height = Math.max(240, Math.floor(r.height));
  }

  function fitView(): void {
    if (!dto) return;
    let minWX: number, maxWX: number, minWY: number, maxWY: number;
    if (bounds && !bounds.empty) {
      // Fit the full art extent (the world rectangle it covers).
      minWX = bounds.worldX;
      maxWX = bounds.worldX + bounds.worldW;
      minWY = bounds.worldY;
      maxWY = bounds.worldY + bounds.worldH;
    } else {
      if (dto.cells.length === 0) return;
      minWX = Infinity;
      maxWX = -Infinity;
      minWY = Infinity;
      maxWY = -Infinity;
      for (const c of dto.cells) {
        const wx = projX(c.x, c.y);
        const wy = projY(c.x, c.y, c.alt);
        if (wx < minWX) minWX = wx;
        if (wx > maxWX) maxWX = wx;
        if (wy < minWY) minWY = wy;
        if (wy > maxWY) maxWY = wy;
      }
      minWX -= HX();
      maxWX += HX();
      minWY -= HY();
      maxWY += HY() + (maxAlt - minAlt) * EL();
    }
    const w = maxWX - minWX || 1;
    const h = maxWY - minWY || 1;
    view.zoom = Math.max(0.05, Math.min(3, Math.min(canvas.width / w, canvas.height / h) * 0.9));
    const cx = (minWX + maxWX) / 2;
    const cy = (minWY + maxWY) / 2;
    view.panX = canvas.width / 2 - cx * view.zoom;
    view.panY = canvas.height / 2 - cy * view.zoom;
    zoomInput.value = String(view.zoom.toFixed(2));
  }

  // altColor maps altitude to a blue(low)->gold(high) ramp; lightDelta shades walls.
  function altColor(alt: number, lightDelta = 0): string {
    const tt = maxAlt > minAlt ? (alt - minAlt) / (maxAlt - minAlt) : 0.5;
    const hue = 210 - tt * 175;
    const light = 50 + tt * 8 + lightDelta;
    return `hsl(${hue.toFixed(0)}, 55%, ${light.toFixed(0)}%)`;
  }

  function draw(): void {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    if (!dto) return;
    ctx.fillStyle = "#14140d";
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    const z = view.zoom;
    const hw = HX() * z;
    const hh = HY() * z;
    // The decorative art layer replaces the analytical blocks once loaded; the
    // blocks stay as a fallback (while art loads) or when topology is toggled on.
    const showArt = view.art && artReady && artImg != null;
    const showBlocks = view.topo || !showArt;
    const cells = showBlocks ? dto.cells : [];
    for (const c of cells) {
      const sx = projX(c.x, c.y) * z + view.panX;
      const sy = projY(c.x, c.y, c.alt) * z + view.panY;
      // cull off-screen
      if (sx < -hw || sx > canvas.width + hw || sy < -hh - 400 || sy > canvas.height + hh) continue;

      const wallH = (c.alt - minAlt) * EL() * z;
      if (wallH > 0.5) {
        // left wall (darker) + right wall
        ctx.fillStyle = altColor(c.alt, -20);
        ctx.beginPath();
        ctx.moveTo(sx - hw, sy);
        ctx.lineTo(sx, sy + hh);
        ctx.lineTo(sx, sy + hh + wallH);
        ctx.lineTo(sx - hw, sy + wallH);
        ctx.closePath();
        ctx.fill();
        ctx.fillStyle = altColor(c.alt, -10);
        ctx.beginPath();
        ctx.moveTo(sx + hw, sy);
        ctx.lineTo(sx, sy + hh);
        ctx.lineTo(sx, sy + hh + wallH);
        ctx.lineTo(sx + hw, sy + wallH);
        ctx.closePath();
        ctx.fill();
      }
      // top face
      ctx.beginPath();
      ctx.moveTo(sx, sy - hh);
      ctx.lineTo(sx + hw, sy);
      ctx.lineTo(sx, sy + hh);
      ctx.lineTo(sx - hw, sy);
      ctx.closePath();
      ctx.fillStyle = altColor(c.alt);
      ctx.fill();
      if (view.walk && !c.w) {
        ctx.fillStyle = "rgba(217,105,79,0.45)"; // obstacle tint
        ctx.fill();
      }
      if (view.grid) {
        ctx.strokeStyle = "rgba(20,20,13,0.35)";
        ctx.lineWidth = 1;
        ctx.stroke();
      }
    }

    if (showArt && artImg) {
      ctx.imageSmoothingEnabled = true;
      ctx.drawImage(artImg, artRWX * z + view.panX, artRWY * z + view.panY, artRWW * z, artRWH * z);
    }

    if (view.spawns) {
      drawSpawns(dto.team0, "rgba(91,140,255,0.55)", "#5b8cff");
      drawSpawns(dto.team1, "rgba(217,105,79,0.55)", "#e0674f");
      drawSpawns(dto.coach, "rgba(217,162,79,0.6)", "#d9a24f", true);
    }

    if (hover) {
      const sx = projX(hover.x, hover.y) * z + view.panX;
      const sy = projY(hover.x, hover.y, hover.alt) * z + view.panY;
      ctx.beginPath();
      ctx.moveTo(sx, sy - hh);
      ctx.lineTo(sx + hw, sy);
      ctx.lineTo(sx, sy + hh);
      ctx.lineTo(sx - hw, sy);
      ctx.closePath();
      ctx.strokeStyle = "#efe9d8";
      ctx.lineWidth = 2;
      ctx.stroke();
    }
  }

  function drawSpawns(cells: MapSpawn[] | null | undefined, fill: string, stroke: string, star = false): void {
    if (!cells) return; // non-arena worlds ship null team/coach arrays
    const z = view.zoom;
    const hw = HX() * z;
    const hh = HY() * z;
    for (const s of cells) {
      const sx = projX(s.x, s.y) * z + view.panX;
      const sy = projY(s.x, s.y, s.z) * z + view.panY;
      ctx.beginPath();
      ctx.moveTo(sx, sy - hh);
      ctx.lineTo(sx + hw, sy);
      ctx.lineTo(sx, sy + hh);
      ctx.lineTo(sx - hw, sy);
      ctx.closePath();
      ctx.fillStyle = fill;
      ctx.fill();
      ctx.strokeStyle = stroke;
      ctx.lineWidth = 2;
      ctx.stroke();
      if (star) {
        ctx.fillStyle = stroke;
        ctx.beginPath();
        ctx.arc(sx, sy, Math.max(2, hh * 0.28), 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }

  // pick the front-most cell whose top diamond contains (mx,my).
  function cellAt(mx: number, my: number): { x: number; y: number; alt: number; w: boolean } | null {
    if (!dto) return null;
    const z = view.zoom;
    const hw = HX() * z;
    const hh = HY() * z;
    for (let i = dto.cells.length - 1; i >= 0; i--) {
      const c = dto.cells[i];
      const sx = projX(c.x, c.y) * z + view.panX;
      const sy = projY(c.x, c.y, c.alt) * z + view.panY;
      if (Math.abs(mx - sx) / hw + Math.abs(my - sy) / hh <= 1) {
        return { x: c.x, y: c.y, alt: c.alt, w: c.w };
      }
    }
    return null;
  }

  function renderReadout(): void {
    if (!dto) return;
    if (hover) {
      readout.innerHTML = `<span class="mono">cell (${hover.x}, ${hover.y})</span> \u00B7 alt <b>${hover.alt}</b> \u00B7 ${
        hover.w ? "walkable" : '<span class="ro-obst">obstacle</span>'
      }`;
    } else {
      const arena = dto.isArena ? ` \u00B7 <b>arena</b> \u00B7 ${dto.team0.length}+${dto.team1.length} spawns` : "";
      const art = artReady ? " \u00B7 art" : "";
      readout.innerHTML = `world <b>${dto.worldId}</b> \u00B7 ${dto.cells.length.toLocaleString()} cells${art}${arena}${
        dto.truncated ? ' \u00B7 <span class="ro-obst">truncated</span>' : ""
      }`;
    }
  }

  function renderLegend(): void {
    if (!dto || dto.cells.length === 0) {
      legend.innerHTML = "";
      return;
    }
    legend.innerHTML = `
      <div class="lg-row"><span class="lg-sw" style="background:${altColor(minAlt)}"></span>low ${minAlt}</div>
      <div class="lg-row"><span class="lg-sw" style="background:${altColor(maxAlt)}"></span>high ${maxAlt}</div>
      ${dto.isArena ? `<div class="lg-row"><span class="lg-sw" style="background:#5b8cff"></span>team A</div><div class="lg-row"><span class="lg-sw" style="background:#e0674f"></span>team B</div><div class="lg-row"><span class="lg-sw" style="background:#d9a24f"></span>coach</div>` : ""}`;
  }

  function loadImage(src: string): Promise<HTMLImageElement | null> {
    return new Promise((res) => {
      const img = new Image();
      const to = setTimeout(() => res(null), 15000);
      img.onload = () => {
        clearTimeout(to);
        res(img);
      };
      img.onerror = () => {
        clearTimeout(to);
        res(null);
      };
      img.src = src;
    });
  }

  // visibleWorldRect maps the current canvas viewport back to world coords.
  function visibleWorldRect(): { wl: number; wt: number; wr: number; wb: number } {
    const z = view.zoom;
    return {
      wl: -view.panX / z,
      wt: -view.panY / z,
      wr: (canvas.width - view.panX) / z,
      wb: (canvas.height - view.panY) / z,
    };
  }

  // requestRender asks the backend to composite ONLY the current viewport at
  // canvas resolution (crisp at any zoom, fast because off-screen sprites are
  // culled). Guarded by renderToken + curId so a stale in-flight render (from a
  // previous view or a superseded map selection) is discarded on arrival.
  async function requestRender(): Promise<void> {
    if (curId < 0 || !bounds || bounds.empty || !view.art) return;
    const rt = ++renderToken;
    const mapAt = curId;
    const { wl, wt, wr, wb } = visibleWorldRect();
    const outW = canvas.width;
    const outH = canvas.height;
    let rd: Awaited<ReturnType<typeof getMapView>> | "timeout";
    try {
      rd = await withTimeout(getMapView(mapAt, wl, wt, wr, wb, outW, outH), 30000);
    } catch {
      return;
    }
    if (rt !== renderToken || mapAt !== curId) return; // superseded
    if (rd === "timeout" || !rd || rd.empty || !rd.dataUrl) return;
    const loaded = await loadImage(rd.dataUrl);
    if (rt !== renderToken || mapAt !== curId) return;
    if (!loaded || !loaded.width) return;
    artImg = loaded;
    artRWX = rd.worldX;
    artRWY = rd.worldY;
    artRWW = rd.worldW;
    artRWH = rd.worldH;
    artReady = true;
    draw();
    renderReadout();
  }

  // scheduleRender debounces viewport re-renders during pan/zoom so we issue one
  // crisp render after the gesture settles; the stale image is transformed live
  // by draw() in the meantime.
  function scheduleRender(delay = 130): void {
    if (renderTimer != null) clearTimeout(renderTimer);
    renderTimer = window.setTimeout(() => {
      renderTimer = null;
      void requestRender();
    }, delay);
  }

  async function selectMap(id: number): Promise<void> {
    const my = ++loadToken;
    curId = id;
    ++renderToken; // invalidate any in-flight viewport render
    const stage = (s: string) => {
      if (my === loadToken) readout.textContent = s;
    };
    const fail = (s: string) => {
      if (my === loadToken) readout.innerHTML = `<span class="ro-obst">${esc(s)}</span>`;
    };
    stage(`Loading topology (world ${id})\u2026`);

    // 1) topology (fallback blocks + spawns + hover)
    let d: Awaited<ReturnType<typeof getMap>> | "timeout";
    try {
      d = await withTimeout(getMap(id), 25000);
    } catch (e) {
      fail(`topology error: ${String(e)}`);
      return;
    }
    if (my !== loadToken) return; // superseded by a newer selection
    if (d === "timeout") {
      fail(`world ${id}: topology timed out`);
      return;
    }
    if (d.error) {
      fail(d.error);
      return;
    }
    dto = d;
    minAlt = Infinity;
    maxAlt = -Infinity;
    for (const c of dto.cells) {
      if (c.alt < minAlt) minAlt = c.alt;
      if (c.alt > maxAlt) maxAlt = c.alt;
    }
    if (!isFinite(minAlt)) {
      minAlt = 0;
      maxAlt = 0;
    }
    hover = null;
    artImg = null;
    artReady = false;
    bounds = null;

    // 2) art extent (fast) drives the auto-fit before any pixels are rendered.
    stage(`Measuring art (world ${id})\u2026`);
    let b: Awaited<ReturnType<typeof getMapBounds>> | "timeout";
    try {
      b = await withTimeout(getMapBounds(id), 30000);
    } catch {
      b = "timeout";
    }
    if (my !== loadToken) return;
    bounds = b !== "timeout" && !b.error ? b : null;

    try {
      resizeCanvas();
      fitView();
      draw();
      renderLegend();
      renderReadout();
    } catch (e) {
      fail(`render error: ${String(e)}`);
      return;
    }

    // 3) first crisp viewport render, filling the fitted view.
    if (bounds && !bounds.empty && view.art) {
      stage(`Rendering art (world ${id})\u2026`);
      await requestRender();
      if (my === loadToken) renderReadout();
    }
  }

  // --- interactions ---
  let dragging = false;
  let lastX = 0;
  let lastY = 0;
  canvas.addEventListener("pointerdown", (e) => {
    dragging = true;
    lastX = e.offsetX;
    lastY = e.offsetY;
    canvas.setPointerCapture(e.pointerId);
  });
  canvas.addEventListener("pointerup", (e) => {
    dragging = false;
    canvas.releasePointerCapture(e.pointerId);
  });
  canvas.addEventListener("pointermove", (e) => {
    if (dragging) {
      view.panX += e.offsetX - lastX;
      view.panY += e.offsetY - lastY;
      lastX = e.offsetX;
      lastY = e.offsetY;
      hover = null;
      draw();
      scheduleRender();
    } else {
      const h = cellAt(e.offsetX, e.offsetY);
      const changed = JSON.stringify(h) !== JSON.stringify(hover);
      hover = h;
      if (changed) {
        draw();
        renderReadout();
      }
    }
  });
  canvas.addEventListener("pointerleave", () => {
    if (hover) {
      hover = null;
      draw();
      renderReadout();
    }
  });
  canvas.addEventListener(
    "wheel",
    (e) => {
      e.preventDefault();
      const f = e.deltaY < 0 ? 1.12 : 1 / 1.12;
      const nz = Math.max(0.2, Math.min(3, view.zoom * f));
      const wx = (e.offsetX - view.panX) / view.zoom;
      const wy = (e.offsetY - view.panY) / view.zoom;
      view.zoom = nz;
      view.panX = e.offsetX - wx * nz;
      view.panY = e.offsetY - wy * nz;
      zoomInput.value = String(nz.toFixed(2));
      draw();
      scheduleRender();
    },
    { passive: false },
  );

  zoomInput.addEventListener("input", () => {
    const nz = parseFloat(zoomInput.value) || 1;
    const cx = canvas.width / 2;
    const cy = canvas.height / 2;
    const wx = (cx - view.panX) / view.zoom;
    const wy = (cy - view.panY) / view.zoom;
    view.zoom = nz;
    view.panX = cx - wx * nz;
    view.panY = cy - wy * nz;
    draw();
    scheduleRender();
  });
  container.querySelector<HTMLButtonElement>("#mapReset")!.addEventListener("click", () => {
    resizeCanvas();
    fitView();
    draw();
    scheduleRender(0);
  });
  const bindToggle = (id: string, key: "grid" | "walk" | "spawns" | "art" | "topo"): void => {
    const el = container.querySelector<HTMLInputElement>("#" + id)!;
    el.addEventListener("change", () => {
      view[key] = el.checked;
      draw();
      if (key === "art" && el.checked) scheduleRender(0);
    });
  };
  bindToggle("tgArt", "art");
  bindToggle("tgTopo", "topo");
  bindToggle("tgWalk", "walk");
  bindToggle("tgSpawns", "spawns");
  bindToggle("tgGrid", "grid");

  const onResize = (): void => {
    resizeCanvas();
    fitView();
    draw();
    scheduleRender(200);
  };
  window.addEventListener("resize", onResize);

  // --- load list + pick ---
  listMaps()
    .then((maps: MapInfo[]) => {
      if (maps.length === 0) {
        readout.innerHTML = `<span class="ro-obst">No worlds. Set the client directory in Settings.</span>`;
        return;
      }
      const arenas = maps.filter((m) => m.isArena);
      const others = maps.filter((m) => !m.isArena);
      const opt = (m: MapInfo) =>
        `<option value="${m.id}">${m.isArena ? "\u2694 " : ""}world ${m.id}${m.isArena ? " (arena)" : ""} \u00B7 ${m.tiles} tiles</option>`;
      pick.innerHTML =
        (arenas.length ? `<optgroup label="Arenas">${arenas.map(opt).join("")}</optgroup>` : "") +
        (others.length ? `<optgroup label="Worlds">${others.map(opt).join("")}</optgroup>` : "");
      badges.innerHTML = `<span class="count">${arenas.length} arenas</span> <span class="count">${maps.length} worlds</span>`;
      pick.addEventListener("change", () => void selectMap(Number(pick.value)));
      // Default to the smallest arena (a real fight map), not a huge overworld.
      const smallest = (list: MapInfo[]) => list.reduce((a, b) => (b.tiles < a.tiles ? b : a));
      const initial = arenas.length ? smallest(arenas).id : smallest(maps).id;
      pick.value = String(initial);
      void selectMap(initial);
    })
    .catch((e) => {
      readout.innerHTML = `<span class="ro-obst">Failed to list maps: ${esc(String(e))}</span>`;
    });
}
