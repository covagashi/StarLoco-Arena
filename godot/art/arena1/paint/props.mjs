// Painted decoration for arena 1 (vector, same hand as ice_block.mjs): light
// from the upper left, 2–3 painted tones per shape, a white catch-light, the
// dark-blue/brown outline. Each prop is drawn around its feet at (0, 0) and
// written as <name>_4x.png / _1x.png with the feet at the bottom centre
// (FOOT px above the bottom edge, at 4x).
//
//   node godot/art/arena1/paint/props.mjs <out_dir>
import { writeFileSync, mkdirSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(join(process.env.HOME, ".claude/skills/loom/package.json"));
const { Resvg } = require("@resvg/resvg-js");
const here = dirname(fileURLToPath(import.meta.url));
const out = process.argv[2] ?? join(here, "../out/paint");
mkdirSync(out, { recursive: true });

export const S = 4, FOOT = 10 * S;
const f = (v) => v.toFixed(1);
const pts = (a) => a.map(([x, y]) => `${f(x)},${f(y)}`).join(" ");
const rot = ([x, y], a) => [x * Math.cos(a) - y * Math.sin(a), x * Math.sin(a) + y * Math.cos(a)];
const add = (p, q) => [p[0] + q[0], p[1] + q[1]];

// deterministic wobble so outlines look drawn, not machined
let seed = 7;
const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);

// --- shapes ------------------------------------------------------------------

// a gem/shard: two long facets split by a ridge, two small tip facets
function shard(x, y, w, h, tilt, c, out = "#163a66") {
  const a = tilt * Math.PI / 180, o = [x, y];
  const P = (px, py) => add(o, rot([px, py], a));
  const bl = P(-w / 2, 0), br = P(w / 2, 0), sl = P(-w / 2 * 0.92, -h * 0.74), sr = P(w / 2 * 0.92, -h * 0.74);
  const rb = P(w * 0.08, 0), rs = P(w * 0.06, -h * 0.76), tip = P(0, -h);
  return `<g stroke-linejoin="round">
  <polygon points="${pts([bl, rb, rs, sl])}" fill="${c[1]}"/>
  <polygon points="${pts([rb, br, sr, rs])}" fill="${c[2]}"/>
  <polygon points="${pts([sl, rs, tip])}" fill="${c[0]}"/>
  <polygon points="${pts([rs, sr, tip])}" fill="${c[1]}"/>
  <polygon points="${pts([P(-w * 0.32, -h * 0.08), P(-w * 0.2, -h * 0.08), P(-w * 0.22, -h * 0.62), P(-w * 0.3, -h * 0.6)])}" fill="#ffffff" opacity="0.55"/>
  <polygon points="${pts([bl, br, sr, tip, sl])}" fill="none" stroke="${out}" stroke-width="${1.1 * S}"/>
  <polyline points="${pts([rb, rs, tip])}" fill="none" stroke="${out}" stroke-width="${0.45 * S}" opacity="0.5"/>
</g>`;
}

// a lumpy blob outline (snow mounds, puffs): ellipse with soft bumps on top
function blobPath(cx, cy, rx, ry, bumps = 5, amp = 0.12) {
  const n = 48, p = [];
  const ph = rnd() * 6;
  for (let i = 0; i < n; i++) {
    const t = (i / n) * Math.PI * 2;
    const up = Math.max(0, -Math.sin(t));                     // bumps only on the upper half
    const k = 1 + amp * up * Math.sin(t * bumps + ph);
    p.push([cx + Math.cos(t) * rx * k, cy + Math.sin(t) * ry * (Math.sin(t) > 0 ? 0.7 : k)]);
  }
  return "M" + p.map(([x, y]) => `${f(x)},${f(y)}`).join(" L") + " Z";
}

let gid = 0;
// snow lump: white top, cold blue underside, outline
function snow(cx, cy, rx, ry, opts = {}) {
  const id = `sn${gid++}`, d = blobPath(cx, cy, rx, ry, opts.bumps ?? 5, opts.amp ?? 0.14);
  return `<defs><linearGradient id="${id}" x1="0" y1="${f(cy - ry)}" x2="0" y2="${f(cy + ry * 0.7)}" gradientUnits="userSpaceOnUse">
    <stop offset="0" stop-color="#ffffff"/><stop offset="0.5" stop-color="#e9f1f9"/><stop offset="1" stop-color="#a9bdd9"/></linearGradient>
    <clipPath id="${id}c"><path d="${d}"/></clipPath></defs>
  <path d="${d}" fill="url(#${id})"/>
  <ellipse cx="${f(cx - rx * 0.3)}" cy="${f(cy - ry * 0.45)}" rx="${f(rx * 0.35)}" ry="${f(ry * 0.22)}" fill="#ffffff" opacity="0.9" clip-path="url(#${id}c)" filter="url(#soft)"/>
  <path d="${d}" fill="none" stroke="${opts.out ?? "#1b3560"}" stroke-width="${1.0 * S}" stroke-linejoin="round" opacity="0.8"/>`;
}

const shadow = (rx, ry) => `<ellipse cx="0" cy="${f(ry * 0.2)}" rx="${f(rx)}" ry="${f(ry)}" fill="#14305e" opacity="0.28" filter="url(#blur)"/>`;

// --- props ---------------------------------------------------------------------

const CRY = ["#c9f4ff", "#5cc6ec", "#2370b4"];
const CRY_D = ["#8fdcf3", "#3a9fd4", "#1b5a98"];
const ICE = ["#ffffff", "#c6ecfa", "#7fbde3"];
const ICE_D = ["#e3f6ff", "#9fd3ee", "#5b9bcc"];

function crystals() {
  seed = 11;
  return shadow(30 * S, 9 * S) +
    shard(9 * S, -2 * S, 9 * S, 26 * S, 24, CRY_D) +
    shard(-11 * S, -1 * S, 9 * S, 22 * S, -28, CRY_D) +
    shard(-2 * S, -2 * S, 12 * S, 44 * S, -4, CRY) +
    shard(13 * S, 1 * S, 8 * S, 18 * S, 40, CRY) +
    shard(-15 * S, 2 * S, 7 * S, 14 * S, -48, CRY) +
    snow(0, 2 * S, 17 * S, 5 * S, { bumps: 6, amp: 0.35 });
}

function spike() {
  seed = 5;
  return shadow(24 * S, 8 * S) +
    shard(8 * S, -1 * S, 9 * S, 30 * S, 18, ICE_D, "#1d4a7c") +
    shard(-8 * S, -1 * S, 8 * S, 22 * S, -22, ICE_D, "#1d4a7c") +
    shard(0, -2 * S, 13 * S, 66 * S, 3, ICE, "#1d4a7c") +
    snow(0, 1 * S, 14 * S, 4.5 * S, { bumps: 5, amp: 0.35 });
}

// pale bare tree: a tapered trunk with a root flare and a slight lean,
// branches that thin to a point, snow lying along the top of each limb
const bez = (p0, p1, p2, p3, t) => {
  const u = 1 - t;
  return [u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0],
    u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1]];
};
// sample a cubic as [point, unit normal on its upper side, t]
function along(c, n = 18) {
  const out = [];
  for (let i = 0; i <= n; i++) {
    const t = i / n, p = bez(...c, t), q = bez(...c, Math.min(1, t + 0.01)), r = bez(...c, Math.max(0, t - 0.01));
    const dx = q[0] - r[0], dy = q[1] - r[1], l = Math.hypot(dx, dy) || 1;
    let nn = [dy / l, -dx / l];
    if (nn[1] > 0) nn = [-nn[0], -nn[1]];   // always the side facing up: snow lands there
    out.push([p, nn, t]);
  }
  return out;
}
// a limb as a filled taper from w0 to w1, light on its upper side
function limb(c, w0, w1) {
  const sm = along(c);
  const L = sm.map(([p, nn, t]) => add(p, [nn[0] * (w0 + (w1 - w0) * t) / 2, nn[1] * (w0 + (w1 - w0) * t) / 2]));
  const R = sm.map(([p, nn, t]) => add(p, [-nn[0] * (w0 + (w1 - w0) * t) / 2, -nn[1] * (w0 + (w1 - w0) * t) / 2]));
  const lit = sm.map(([p, nn, t]) => add(p, [nn[0] * (w0 + (w1 - w0) * t) * 0.2, nn[1] * (w0 + (w1 - w0) * t) * 0.2]));
  return `<polygon points="${pts([...L, ...R.reverse()])}" fill="#bfa47c" stroke="#4a3524" stroke-width="${0.9 * S}" stroke-linejoin="round"/>
  <polygon points="${pts([...L, ...lit.reverse()])}" fill="#efe3c6" opacity="0.85"/>`;
}
// snow riding the upper side of a limb from t0 to its tip, lumpy on top
function snowOn(c, w0, w1, t0, thick) {
  const sm = along(c, 24).filter(([, , t]) => t >= t0);
  const base = sm.map(([p, nn, t]) => add(p, [nn[0] * (w0 + (w1 - w0) * t) * 0.35, nn[1] * (w0 + (w1 - w0) * t) * 0.35]));
  const topp = sm.map(([p, nn, t], i) => {
    const k = thick * Math.sin(Math.PI * (t - t0) / (1 - t0 + 0.0001)) ** 0.6 * (1 + 0.12 * Math.sin(i * 0.8));
    return add(p, [nn[0] * ((w0 + (w1 - w0) * t) * 0.35 + k), nn[1] * ((w0 + (w1 - w0) * t) * 0.35 + k)]);
  });
  const d = [...topp, ...base.reverse()];
  return `<polygon points="${pts(d)}" fill="#f4f8fd" stroke="#1b3560" stroke-width="${0.8 * S}" stroke-linejoin="round" stroke-opacity="0.75"/>
  <polyline points="${pts(base.slice().reverse())}" fill="none" stroke="#9fb4d1" stroke-width="${0.8 * S}" opacity="0.8"/>`;
}
function tree() {
  seed = 3;
  const B1 = [[1 * S, -30 * S], [8 * S, -36 * S], [15 * S, -38 * S], [22 * S, -50 * S]];
  const B2 = [[-1 * S, -40 * S], [-7 * S, -45 * S], [-15 * S, -47 * S], [-19 * S, -60 * S]];
  const B3 = [[0, -22 * S], [-6 * S, -24 * S], [-12 * S, -26 * S], [-16 * S, -33 * S]];
  const T1 = [[14 * S, -39 * S], [17 * S, -43 * S], [17 * S, -47 * S], [15 * S, -52 * S]];   // twig off B1
  const B4 = [[0, -48 * S], [2 * S, -54 * S], [5 * S, -58 * S], [4 * S, -66 * S]];            // the crown
  const trunk = `M${f(-9 * S)},${f(1 * S)} C${f(-5 * S)},${f(-2 * S)} ${f(-5 * S)},${f(-6 * S)} ${f(-4.5 * S)},${f(-14 * S)}
    C${f(-4 * S)},${f(-28 * S)} ${f(-1.5 * S)},${f(-38 * S)} ${f(-1 * S)},${f(-50 * S)}
    L${f(2 * S)},${f(-50 * S)} C${f(2.5 * S)},${f(-36 * S)} ${f(5 * S)},${f(-24 * S)} ${f(5 * S)},${f(-12 * S)}
    C${f(5 * S)},${f(-5 * S)} ${f(6 * S)},${f(-2 * S)} ${f(10 * S)},${f(1 * S)} Z`;
  return shadow(22 * S, 7 * S) +
    limb(B3, 3.4 * S, 0.8 * S) + limb(B2, 3.8 * S, 0.8 * S) + limb(B1, 4 * S, 0.9 * S) + limb(T1, 1.8 * S, 0.6 * S) + limb(B4, 3 * S, 0.8 * S) +
    `<defs><linearGradient id="bark" x1="${-8 * S}" y1="0" x2="${8 * S}" y2="0" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#f3e8cc"/><stop offset="0.45" stop-color="#d2bb92"/><stop offset="1" stop-color="#977b55"/></linearGradient></defs>
    <path d="${trunk}" fill="url(#bark)" stroke="#4a3524" stroke-width="${1.1 * S}" stroke-linejoin="round"/>
    <g stroke="#7a5e3e" stroke-width="${0.5 * S}" fill="none" stroke-linecap="round" opacity="0.65">
      <path d="M${f(2 * S)},${f(-6 * S)} q${f(1 * S)},${f(-5 * S)} 0,${f(-10 * S)}"/>
      <path d="M${f(-2.5 * S)},${f(-24 * S)} q${f(1.2 * S)},${f(-3 * S)} ${f(0.4 * S)},${f(-7 * S)}"/>
      <path d="M${f(1.5 * S)},${f(-40 * S)} l${f(-0.6 * S)},${f(-4 * S)}"/>
    </g>` +
    snowOn(B1, 4 * S, 0.9 * S, 0.25, 3 * S) + snowOn(B2, 3.8 * S, 0.8 * S, 0.3, 2.8 * S) +
    snowOn(B3, 3.4 * S, 0.8 * S, 0.35, 2.2 * S) +
    snow(0.5 * S, -50 * S, 4.2 * S, 2.6 * S, { bumps: 3, amp: 0.25 }) +
    snow(0, 1 * S, 15 * S, 4.5 * S, { bumps: 5, amp: 0.3 });
}

// --- write ---------------------------------------------------------------------

export const PROPS = { crystals: [crystals, 70, 64], spike: [spike, 56, 80], tree: [tree, 60, 80] };
for (const [name, [fn, w, h]] of Object.entries(PROPS)) {
  gid = 0;
  const W = w * S, Hh = h * S;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${Hh}" viewBox="${-W / 2} ${-(Hh - FOOT)} ${W} ${Hh}">
<defs><filter id="blur" x="-30%" y="-80%" width="160%" height="260%"><feGaussianBlur stdDeviation="${3 * S}"/></filter>
<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${1.2 * S}"/></filter></defs>
${fn()}
</svg>`;
  writeFileSync(join(out, `${name}.svg`), svg);
  for (const [tag, ww] of [["4x", W], ["1x", W / S]])
    writeFileSync(join(out, `${name}_${tag}.png`), new Resvg(svg, { fitTo: { mode: "width", value: ww } }).render().asPng());
  console.log(name, `${W}x${Hh}`);
}
