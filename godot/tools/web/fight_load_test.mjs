// S47: a fight loads its arena without renderer errors on the web. Serves
// <web dir> on 127.0.0.1:8091 as back_test.mjs does, presses JUGAR (a demo
// account), creates the coach, recruits a fighter, then plays N practice
// fights (ENTRENAMIENTO, then the leave button ⇥ and Enter), counting the
// console errors each arena's load prints ('Parameter "material" is null'
// was one, S47). With a server that hands the arenas out in turn, N = 6
// covers the release set. Exits 1 if any fight printed an engine error.
//
//   PLAYWRIGHT=<path to playwright/index.mjs> node godot/tools/web/fight_load_test.mjs \
//       <web dir> <ws url> <out dir> [N]
//
// Needs a game server with ws_addr and limits.demo_accounts on.
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { gzipSync } from "node:zlib";
import { extname, join } from "node:path";
const { chromium } = await import(process.env.PLAYWRIGHT || "playwright");

const [dir, ws, out, nArg] = process.argv.slice(2);
const N = Number(nArg || 6);
const TYPES = { ".html": "text/html", ".js": "application/javascript", ".wasm": "application/wasm",
	".pck": "application/octet-stream", ".png": "image/png", ".json": "application/json",
	".zip": "application/zip" };
const GZIP = new Set([".html", ".js", ".wasm", ".pck", ".json"]);
const cache = new Map();

const server = createServer(async (req, res) => {
	const path = join(dir, decodeURIComponent(new URL(req.url, "http://x").pathname));
	try {
		await stat(path);
	} catch {
		res.writeHead(404).end();
		return;
	}
	const ext = extname(path);
	const headers = { "Content-Type": TYPES[ext] || "application/octet-stream",
		"Cross-Origin-Opener-Policy": "same-origin", "Cross-Origin-Embedder-Policy": "require-corp" };
	let body = await readFile(path);
	if (GZIP.has(ext) && /gzip/.test(req.headers["accept-encoding"] || "")) {
		if (!cache.has(path)) cache.set(path, gzipSync(body, { level: 6 }));
		body = cache.get(path);
		headers["Content-Encoding"] = "gzip";
	}
	headers["Content-Length"] = body.length;
	res.writeHead(200, headers).end(body);
});

await new Promise((ok) => server.listen(8091, "127.0.0.1", ok));

const browser = await chromium.launch({ channel: "chromium", args: ["--no-sandbox", "--use-angle=vulkan", "--ignore-gpu-blocklist"] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
// CONSOLE=all prints every console line whole (a debug export's backtraces)
const all = process.env.CONSOLE === "all";
let errors = [];
let world = "?";
page.on("console", (m) => {
	const t = m.text();
	const w = /entering instance world=(\d+)/.exec(t);
	if (w) world = w[1];
	if (/^ERROR:/.test(t)) errors.push(t);
	if (all || /error/i.test(m.type())) console.log("[console]", all ? t : t.slice(0, 200));
});
const mark = (k) => page.evaluate((k) => (window.__pippop || {})[k] ?? null, k).catch(() => null);
const until = async (k, ms) => { const end = Date.now() + ms; while (Date.now() < end) { const v = await mark(k); if (v !== null) return v; await page.waitForTimeout(500); } return null; };
const gui = () => mark("gui");
const shot = (n) => page.screenshot({ path: `${out}/${n}.png`, timeout: 120000 });
const log = async (what) => console.log(what, JSON.stringify(await gui()), "history.length=", await page.evaluate(() => history.length));
await page.goto(`http://127.0.0.1:8091/index.html?server=${encodeURIComponent(ws)}`);
console.log("login at", await until("login", 900000));
page.on("dialog", (d) => d.accept());
await page.waitForTimeout(2000);
await page.mouse.click(1035, 430);                 // JUGAR
console.log("creation at", await until("creation", 180000));
await page.waitForTimeout(3000);
await page.mouse.click(1120, 485);                 // ¡CREAR!
await page.waitForTimeout(15000);
const closeAll = async () => {
	for (let i = 0; i < 4; i++) {
		const g = await gui();
		if (!g || g.open.length === 0) break;
		await page.keyboard.press("Escape");
		await page.waitForTimeout(1500);
	}
};
await closeAll();
await page.mouse.click(1175, 316);                 // Historia → RECLUTAR
await page.waitForTimeout(4000);
await page.mouse.click(435, 666);
await page.keyboard.type("Probador");
await page.mouse.click(700, 666);                  // ¡RECLUTAR!
await page.waitForTimeout(5000);
await closeAll();
const guarded = () => page.evaluate(() => typeof window.onbeforeunload === "function");
let bad = 0;
for (let i = 1; i <= N; i++) {
	errors = [];
	world = "?";
	await page.mouse.click(1130, 147);             // ENTRENAMIENTO
	let fight = false;
	for (let k = 0; k < 60 && !fight; k++) { await page.waitForTimeout(1000); fight = await guarded(); }
	await page.waitForTimeout(6000);
	await shot(`fight-${i}-world${world}`);
	console.log(`fight ${i}: world ${world}, ${fight ? "started" : "DID NOT START"}, ${errors.length} engine errors`);
	for (const e of [...new Set(errors)]) console.log("   ", e.split("\n")[0]);
	if (!fight || errors.length) bad++;
	await page.mouse.click(1245, 34);              // leave ⇥
	await page.waitForTimeout(1500);
	await page.keyboard.press("Enter");            // its confirmation
	for (let k = 0; k < 30 && (await guarded()); k++) await page.waitForTimeout(1000);
	await page.waitForTimeout(6000);
	await closeAll();
}
console.log(bad ? `FAIL ${bad} of ${N} fights` : `PASS ${N} fights, no engine errors`);
await browser.close();
server.close();
process.exit(bad ? 1 : 0);
