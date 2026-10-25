// Painted ice block (vector, Ankama-like): drawn as SVG at 4x the game cell
// (86 px wide, 2:1 top), rasterised with resvg. No 3D, no lights: every
// shadow and highlight is painted. loom textures fill the faces softly.
//
//   node godot/art/arena1/paint/ice_block.mjs <out_dir>
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(join(process.env.HOME, ".claude/skills/loom/package.json"));
const { Resvg } = require("@resvg/resvg-js");
const here = dirname(fileURLToPath(import.meta.url));
const out = process.argv[2] ?? join(here, "../out/paint");
mkdirSync(out, { recursive: true });

const S = 4, HW = 43 * S, HH = 21.5 * S, H = 37 * S, PAD = 6 * S;
const W = 2 * HW + 2 * PAD, CY = PAD + 12 * S + HH, CX = W / 2, IMG_H = CY + HH + H + PAD + 4 * S;
const T = [CX, CY - HH], R = [CX + HW, CY], B = [CX, CY + HH], L = [CX - HW, CY];
const dn = (p, d) => [p[0], p[1] + d];
const P = (...ps) => ps.map((p) => p.map((v) => v.toFixed(1)).join(",")).join(" ");
const tex = (name) => "data:image/png;base64," + readFileSync(join(here, `../out/${name}/${name}_albedo.png`)).toString("base64");

// snow: top surface raised by SN, front band thickness BAND, drips below it
const SN = 3 * S, BAND = 4 * S;
const lerp = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
// drips along an edge from a to b: [t, width(t), length(px)]
function dripEdge(a, b, drips) {
  let d = "";
  let t0 = 0;
  for (const [t, w, len] of drips) {
    const s = lerp(a, b, t - w / 2), e = lerp(a, b, t + w / 2), tip = dn(lerp(a, b, t), len);
    const k = Math.hypot(e[0] - s[0], e[1] - s[1]) * 0.42;
    d += ` L${P(s)} C${P(dn(s, len * 0.75))} ${P([tip[0] - k, tip[1]])} ${P(tip)}` +
         ` C${P([tip[0] + k, tip[1]])} ${P(dn(e, len * 0.75))} ${P(e)}`;
    t0 = t + w / 2;
  }
  return d + ` L${P(b)}`;
}
const LB = [[0.1, 0.09, 5 * S], [0.27, 0.12, 10 * S], [0.45, 0.08, 4 * S], [0.62, 0.13, 13 * S], [0.85, 0.1, 6 * S]];
const BR = [[0.12, 0.1, 7 * S], [0.33, 0.12, 12 * S], [0.52, 0.08, 4.5 * S], [0.7, 0.11, 9 * S], [0.9, 0.08, 5 * S]];
const bandTopL = dn(L, -SN), bandTopB = dn(B, -SN), bandTopR = dn(R, -SN);
const lowL = dn(L, -SN + BAND), lowB = dn(B, -SN + BAND), lowR = dn(R, -SN + BAND);
const lowerEdge = `M${P(lowL)}` + dripEdge(lowL, lowB, LB) + dripEdge(lowB, lowR, BR);
const bandPath = `M${P(bandTopL)} L${P(bandTopB)} L${P(bandTopR)} L${P(lowR)}` +
  dripEdge(lowR, lowB, BR.map(([t, w, l]) => [1 - t, w, l]).reverse()) +
  dripEdge(lowB, lowL, LB.map(([t, w, l]) => [1 - t, w, l]).reverse()) + " Z";
// top of the snow: the diamond raised, corners softened
const top = [dn(T, -SN), dn(R, -SN), dn(B, -SN), dn(L, -SN)];
const soft = (pts, r) => {
  let d = "";
  pts.forEach((p, i) => {
    const prev = pts[(i + pts.length - 1) % pts.length], next = pts[(i + 1) % pts.length];
    const a = lerp(p, prev, r), b = lerp(p, next, r);
    d += (i ? " L" : "M") + P(a) + ` Q${P(p)} ${P(b)}`;
  });
  return d + " Z";
};
const topPath = soft(top, 0.06);
// a face's affine frame for patterns: unit square -> parallelogram
const frame = (o, u, v) => `matrix(${u[0]},${u[1]},${v[0]},${v[1]},${o[0]},${o[1]})`;

const svg = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${W}" height="${IMG_H}" viewBox="0 0 ${W} ${IMG_H}">
<defs>
  <linearGradient id="iceL" x1="0" y1="${CY}" x2="0" y2="${B[1] + H}" gradientUnits="userSpaceOnUse">
    <stop offset="0" stop-color="#d4f2fc"/><stop offset="0.3" stop-color="#9ad6f1"/>
    <stop offset="0.66" stop-color="#62acdb"/><stop offset="0.8" stop-color="#3b7fc0"/><stop offset="1" stop-color="#284f91"/>
  </linearGradient>
  <linearGradient id="iceR" x1="0" y1="${CY}" x2="0" y2="${B[1] + H}" gradientUnits="userSpaceOnUse">
    <stop offset="0" stop-color="#a9def4"/><stop offset="0.3" stop-color="#6fb7e2"/>
    <stop offset="0.66" stop-color="#4489c4"/><stop offset="0.8" stop-color="#2d63a3"/><stop offset="1" stop-color="#1f3f78"/>
  </linearGradient>
  <radialGradient id="snowTop" cx="${CX - HW * 0.25}" cy="${CY - HH * 0.35}" r="${HW * 1.15}" gradientUnits="userSpaceOnUse">
    <stop offset="0" stop-color="#ffffff"/><stop offset="0.55" stop-color="#eef4fa"/><stop offset="1" stop-color="#c3d3e6"/>
  </radialGradient>
  <linearGradient id="snowBand" x1="0" y1="${CY - SN}" x2="0" y2="${B[1] + 12 * S}" gradientUnits="userSpaceOnUse">
    <stop offset="0" stop-color="#f6faff"/><stop offset="0.45" stop-color="#dfe9f4"/><stop offset="1" stop-color="#a9bdd8"/>
  </linearGradient>
  <pattern id="texIceL" patternUnits="userSpaceOnUse" width="1" height="1" patternTransform="${frame(L, [HW, HH], [0, H])}">
    <image width="1" height="1" preserveAspectRatio="none" xlink:href="${tex("ice_body")}"/></pattern>
  <pattern id="texIceR" patternUnits="userSpaceOnUse" width="1" height="1" patternTransform="${frame(B, [HW, -HH], [0, H])}">
    <image width="1" height="1" preserveAspectRatio="none" xlink:href="${tex("ice_body")}"/></pattern>
  <pattern id="texSnow" patternUnits="userSpaceOnUse" width="1" height="1" patternTransform="${frame(top[0], [HW, HH], [-HW, HH])}">
    <image width="1" height="1" preserveAspectRatio="none" xlink:href="${tex("snow_soft")}"/></pattern>
  <clipPath id="faces"><polygon points="${P(L, B, R, dn(R, H), dn(B, H), dn(L, H))}"/></clipPath>
  <clipPath id="topClip"><path d="${topPath}"/></clipPath>
  <filter id="b2" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="${2 * S}"/></filter>
  <filter id="b1"><feGaussianBlur stdDeviation="${0.6 * S}"/></filter>
  <filter id="b4" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="${4 * S}"/></filter>
</defs>

<!-- ice faces: gradient, then the loom texture multiplied in, then paint -->
<polygon points="${P(L, B, dn(B, H), dn(L, H))}" fill="url(#iceL)"/>
<polygon points="${P(B, R, dn(R, H), dn(B, H))}" fill="url(#iceR)"/>
<g clip-path="url(#faces)" style="mix-blend-mode:multiply" opacity="0.45">
  <polygon points="${P(L, B, dn(B, H), dn(L, H))}" fill="url(#texIceL)"/>
  <polygon points="${P(B, R, dn(R, H), dn(B, H))}" fill="url(#texIceR)"/>
</g>
<g clip-path="url(#faces)">
  <!-- light caught inside the ice: soft vertical glows and a few fractures -->
  <g filter="url(#b2)" opacity="0.55" fill="#e8fbff">
    <polygon points="${P(lerp(L, B, 0.18), lerp(L, B, 0.3), dn(lerp(L, B, 0.26), H * 0.7), dn(lerp(L, B, 0.14), H * 0.6))}"/>
    <polygon points="${P(lerp(L, B, 0.6), lerp(L, B, 0.66), dn(lerp(L, B, 0.64), H * 0.55), dn(lerp(L, B, 0.57), H * 0.5))}"/>
    <polygon points="${P(lerp(B, R, 0.35), lerp(B, R, 0.42), dn(lerp(B, R, 0.4), H * 0.45), dn(lerp(B, R, 0.33), H * 0.4))}" opacity="0.6"/>
  </g>
  <g stroke="#f4feff" stroke-linecap="round" fill="none" opacity="0.7">
    <path d="M${P(dn(lerp(L, B, 0.3), H * 0.3))} q${3 * S},${5 * S} ${4 * S},${14 * S}" stroke-width="${0.7 * S}" opacity="0.8"/>
    <path d="M${P(dn(lerp(B, R, 0.62), H * 0.26))} q${-1 * S},${6 * S} ${1.5 * S},${11 * S}" stroke-width="${0.5 * S}" opacity="0.6"/>
  </g>
  <!-- deep band at the foot gets a cold rim light along its top -->
  <path d="M${P(dn(L, H * 0.74))} L${P(dn(B, H * 0.74))} L${P(dn(R, H * 0.74))}" stroke="#9fd2f2" stroke-width="${1.2 * S}" fill="none" opacity="0.5" filter="url(#b1)"/>
  <!-- the snow casts a soft shadow on the ice right under its drips -->
  <path d="${lowerEdge} L${P(dn(lowR, -20 * S))} L${P(dn(lowL, -20 * S))} Z" transform="translate(${1.5 * S},${4 * S})" fill="#1d4f8f" opacity="0.45" filter="url(#b2)"/>
</g>
<!-- front edge highlight, bottom rim -->
<line x1="${B[0]}" y1="${B[1]}" x2="${B[0]}" y2="${B[1] + H}" stroke="#e9fbff" stroke-width="${1.2 * S}" opacity="0.8" filter="url(#b1)"/>
<polyline points="${P(dn(L, H), dn(B, H), dn(R, H))}" stroke="#18315f" stroke-width="${1.4 * S}" fill="none" opacity="0.6"/>

<!-- snow band with its drips -->
<path d="${bandPath}" fill="url(#snowBand)"/>
<path d="${lowerEdge}" fill="none" stroke="#9fb4d1" stroke-width="${1.6 * S}" opacity="0.55" filter="url(#b1)" transform="translate(0,${-1.2 * S})"/>
<!-- snow top -->
<path d="${topPath}" fill="url(#snowTop)"/>
<g clip-path="url(#topClip)">
  <path d="${topPath}" fill="url(#texSnow)" style="mix-blend-mode:multiply" opacity="0.35"/>
  <g filter="url(#b4)">
    <ellipse cx="${CX + HW * 0.35}" cy="${CY + HH * 0.25}" rx="${HW * 0.35}" ry="${HH * 0.28}" fill="#a8bdd9" opacity="0.45"/>
    <ellipse cx="${CX - HW * 0.05}" cy="${CY + HH * 0.55}" rx="${HW * 0.3}" ry="${HH * 0.2}" fill="#b5c7df" opacity="0.4"/>
    <ellipse cx="${CX - HW * 0.35}" cy="${CY - HH * 0.3}" rx="${HW * 0.28}" ry="${HH * 0.2}" fill="#ffffff" opacity="0.9"/>
    <ellipse cx="${CX + HW * 0.1}" cy="${CY - HH * 0.15}" rx="${HW * 0.2}" ry="${HH * 0.14}" fill="#ffffff" opacity="0.7"/>
  </g>
</g>
<!-- the lip where the top turns into the band -->
<path d="M${P(dn(L, -SN))} L${P(dn(B, -SN))} L${P(dn(R, -SN))}" stroke="#ffffff" stroke-width="${1.2 * S}" fill="none" opacity="0.9" filter="url(#b1)"/>

<!-- soft dark outline around the whole silhouette -->
<g fill="none" stroke="#1b3560" stroke-width="${1.1 * S}" stroke-linejoin="round" opacity="0.75">
  <path d="${topPath}" stroke-opacity="0.35"/>
  <path d="M${P(dn(L, -SN))} L${P(lowL)}${dripEdge(lowL, lowB, LB)}${dripEdge(lowB, lowR, BR)} L${P(dn(R, -SN))}"/>
  <polyline points="${P(lowL, dn(L, H), dn(B, H), dn(R, H), lowR)}"/>
</g>
</svg>`;

writeFileSync(join(out, "ice_block.svg"), svg);
for (const [name, w] of [["ice_block_4x", W], ["ice_block_1x", W / S]]) {
  const png = new Resvg(svg, { fitTo: { mode: "width", value: w } }).render().asPng();
  writeFileSync(join(out, `${name}.png`), png);
}
console.log("ice_block ->", out, `${W}x${IMG_H}`);
