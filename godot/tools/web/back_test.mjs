// S47 W7: the browser's Back closes the window on top. Serves <web dir>
// (an export + tools/web/pack_web.gd) on 127.0.0.1:8091, presses JUGAR (a
// demo account), creates the coach, then opens windows and goes Back,
// printing window.__pippop.gui (the open windows, our history entries) and
// a screenshot per step in <out dir>.
//
//   PLAYWRIGHT=<path to playwright/index.mjs> node godot/tools/web/back_test.mjs \
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

// S47 W7: the browser's Back closes the window on top
const browser = await chromium.launch({ channel: "chromium", args: ["--no-sandbox", "--use-angle=vulkan", "--ignore-gpu-blocklist"] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on("console", (m) => { if (/error/i.test(m.type())) console.log("[console]", m.text().slice(0, 200)); });
const mark = (k) => page.evaluate((k) => (window.__pippop || {})[k] ?? null, k).catch(() => null);
const until = async (k, ms) => { const end = Date.now() + ms; while (Date.now() < end) { const v = await mark(k); if (v !== null) return v; await page.waitForTimeout(500); } return null; };
const gui = () => mark("gui");
const shot = (n) => page.screenshot({ path: `${out}/${n}.png`, timeout: 120000 });
const log = async (what) => console.log(what, JSON.stringify(await gui()), "history.length=", await page.evaluate(() => history.length));
await page.goto(`http://127.0.0.1:8091/index.html?server=${encodeURIComponent(ws)}`);
console.log("login at", await until("login", 900000));
await page.waitForTimeout(2000);
await page.mouse.click(1035, 430);
console.log("creation at", await until("creation", 180000));
await page.waitForTimeout(3000);
await page.mouse.click(1120, 485);   // ¡CREAR!
await page.waitForTimeout(15000);
await shot("1-after-create");
await log("after create:");
const step = async (name, fn) => { await fn(); await page.waitForTimeout(2500); await shot(name); await log(name + ":"); };
// close whatever the first visit opened (intro) with Back, until nothing is open
for (let i = 0; i < 3; i++) {
	const g = await gui();
	if (!g || g.open.length === 0) break;
	await step(`2-back-${i}`, () => page.goBack({ waitUntil: "commit", timeout: 5000 }).catch(() => {}));
}
await step("3-open-logros", () => page.mouse.click(126, 346));
await step("4-back", () => page.goBack({ waitUntil: "commit", timeout: 5000 }).catch(() => {}));
await step("5-open-logros-again", () => page.mouse.click(126, 346));
await step("6-close-x", () => page.keyboard.press("Escape"));
await step("7-open-inventario", () => page.mouse.click(144, 190));
await step("8-back", () => page.goBack({ waitUntil: "commit", timeout: 5000 }).catch(() => {}));
console.log("url at end:", page.url());
await browser.close();
server.close();
