// S47 W7: in a fight the browser asks before leaving the page. Serves <web
// dir> on 127.0.0.1:8091 as back_test.mjs does, presses JUGAR (a demo
// account), creates the coach, recruits a fighter (Historia → RECLUTAR),
// starts the practice fight (ENTRENAMIENTO), then goes Back: the page must
// raise a beforeunload dialog and, dismissed, stay in the fight. Back in
// the lobby nothing asks. Prints PASS/FAIL lines, screenshots in <out dir>.
//
//   PLAYWRIGHT=<path to playwright/index.mjs> node godot/tools/web/leave_test.mjs \
//       <web dir> <ws url> <out dir>
//
// Needs a game server with ws_addr and limits.demo_accounts on.
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { gzipSync } from "node:zlib";
import { extname, join } from "node:path";
const { chromium } = await import(process.env.PLAYWRIGHT || "playwright");

const [dir, ws, out] = process.argv.slice(2);
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
page.on("console", (m) => { if (all || /error/i.test(m.type())) console.log("[console]", all ? m.text() : m.text().slice(0, 200)); });
const stepLog = (what) => console.log("[step]", what);
const mark = (k) => page.evaluate((k) => (window.__pippop || {})[k] ?? null, k).catch(() => null);
const until = async (k, ms) => { const end = Date.now() + ms; while (Date.now() < end) { const v = await mark(k); if (v !== null) return v; await page.waitForTimeout(500); } return null; };
const gui = () => mark("gui");
const shot = (n) => page.screenshot({ path: `${out}/${n}.png`, timeout: 120000 });
const log = async (what) => console.log(what, JSON.stringify(await gui()), "history.length=", await page.evaluate(() => history.length));
await page.goto(`http://127.0.0.1:8091/index.html?server=${encodeURIComponent(ws)}`);
console.log("login at", await until("login", 900000));
let dialogs = [];
page.on("dialog", async (d) => { dialogs.push(d.type()); await d.dismiss(); });
const guarded = () => page.evaluate(() => typeof window.onbeforeunload === "function");
const fails = [];
const check = (ok, what) => { console.log(ok ? "PASS" : "FAIL", what); if (!ok) fails.push(what); };
await page.waitForTimeout(2000);
await page.mouse.click(1035, 430);                 // JUGAR
console.log("creation at", await until("creation", 180000));
await page.waitForTimeout(3000);
await page.mouse.click(1120, 485);                 // ¡CREAR!
await page.waitForTimeout(15000);
for (let i = 0; i < 4; i++) {                      // the intro, closed with Escape
	const g = await gui();
	if (!g || g.open.length === 0) break;
	await page.keyboard.press("Escape");
	await page.waitForTimeout(1500);
}
await shot("1-lobby");
check(!(await guarded()), "lobby: nothing asks before leaving");
stepLog("recruit screen");
await page.mouse.click(1175, 316);                 // Historia → RECLUTAR
await page.waitForTimeout(4000);
await shot("2-recruit");
await page.mouse.click(435, 666);                  // the name field
await page.keyboard.type("Probador");
stepLog("recruit");
await page.mouse.click(700, 666);                  // ¡RECLUTAR!
await page.waitForTimeout(5000);
for (let i = 0; i < 3; i++) {                      // whatever opened after it
	const g = await gui();
	if (!g || g.open.length === 0) break;
	await page.keyboard.press("Escape");
	await page.waitForTimeout(1500);
}
await shot("3-recruited");
stepLog("training");
await page.mouse.click(1130, 147);                 // ENTRENAMIENTO
let fight = false;
for (let i = 0; i < 60 && !fight; i++) { await page.waitForTimeout(1000); fight = await guarded(); }
await page.waitForTimeout(4000);
await shot("4-fight");
check(fight, "fight: the leave guard is on");
stepLog("back");
const before = page.url();
dialogs = [];
await page.goBack({ waitUntil: "commit", timeout: 8000 }).catch(() => {});
await page.waitForTimeout(3000);
await shot("5-after-back");
check(dialogs.includes("beforeunload"), `Back in a fight raises the browser's question (${JSON.stringify(dialogs)})`);
check(page.url() === before && (await guarded()), "dismissed, the page stays in the fight");
console.log("url:", page.url());
await browser.close();
server.close();
process.exit(fails.length ? 1 : 0);
