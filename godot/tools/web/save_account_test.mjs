// S51 «Guardar mi progreso» in the web build: JUGAR makes a demo account,
// Opciones → «Guardar mi progreso» saves it with an email, a reload's JUGAR
// comes back in with email + the browser's device key (user:// in
// IndexedDB), and a fresh browser gets in with «Ya tengo cuenta». Serves
// <web dir> on 127.0.0.1:8091 as leave_test.mjs does; PASS/FAIL lines,
// screenshots in <out dir>.
//
//   PLAYWRIGHT=<path to playwright/index.mjs> node godot/tools/web/save_account_test.mjs \
//       <web dir> <ws url> <out dir> <server log>
//
// The server log tells what the server did (saved, key issued, logins).
// Needs a game server with ws_addr and limits.demo_accounts on.
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { gzipSync } from "node:zlib";
import { extname, join } from "node:path";
const { chromium } = await import(process.env.PLAYWRIGHT || "playwright");

const [dir, ws, out, serverLog] = process.argv.slice(2);
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
const EMAIL = `web.${Date.now() % 100000}@example.com`, PASS = "webpass123";
const fails = [];
const check = (ok, what) => { console.log(ok ? "PASS" : "FAIL", what); if (!ok) fails.push(what); };
const open = async () => ((await gui()) || {}).open || [];
const closeAll = async () => {
	for (let i = 0; i < 5; i++) {
		if ((await open()).length === 0) break;
		await page.keyboard.press("Escape");
		await page.waitForTimeout(1500);
	}
};
const srv = () => readFileSync(serverLog, "utf8");
const count = (re) => (srv().match(re) || []).length;
const url = `http://127.0.0.1:8091/index.html?server=${encodeURIComponent(ws)}`;

await page.goto(url);
console.log("login at", await until("login", 900000));
await page.waitForTimeout(2500);
await shot("w1-login");
await page.mouse.click(1035, 403);                 // JUGAR
console.log("creation at", await until("creation", 180000));
await page.waitForTimeout(3000);
await page.mouse.click(1120, 485);                 // ¡CREAR!
await page.waitForTimeout(15000);
await closeAll();
await shot("w2-lobby");
stepLog("options");
await page.mouse.click(1236, 48);                  // the menu
await page.waitForTimeout(2500);
await log("menu");
await shot("w3-menu");
await page.mouse.click(640, 225);                  // Opciones
await page.waitForTimeout(2500);
await page.mouse.move(640, 400);
for (let i = 0; i < 10; i++) { await page.mouse.wheel(0, 400); await page.waitForTimeout(150); }
await page.waitForTimeout(1000);
await shot("w4-options");
await page.mouse.click(273, 573);                  // Guardar mi progreso
await page.waitForTimeout(2500);
check((await open()).includes("saveAccountDialog"), "Opciones opens the save form");
await page.keyboard.type(EMAIL);                   // the email has the focus
await page.keyboard.press("Tab");
await page.keyboard.type(PASS);
await page.keyboard.press("Tab");
await page.keyboard.type(PASS);
await shot("w5-form");
await page.keyboard.press("Enter");
await page.waitForTimeout(4000);
await shot("w6-saved");
check(count(new RegExp(`demo account saved.*email=${EMAIL.replace(".", "\\.")}`)) === 1, "the server saved the demo account under the email");

stepLog("reload: JUGAR with the device key");
await page.goto(url);
console.log("login at", await until("login", 900000));
await page.waitForTimeout(2500);
const before = count(new RegExp(`auth attempt.*login=${EMAIL}`));
await page.mouse.click(1035, 403);                 // JUGAR
await page.waitForTimeout(12000);
await closeAll();
await shot("w7-back-in");
check(count(new RegExp(`auth attempt.*login=${EMAIL}`)) === before + 1 && (await mark("creation")) === null,
	"the reloaded page logs in with the email (no new coach)");

stepLog("a fresh browser: Ya tengo cuenta");
const ctx2 = await browser.newContext({ viewport: { width: 1280, height: 720 } });
const page2 = await ctx2.newPage();
await page2.goto(url);
const until2 = async (k, ms) => { const end = Date.now() + ms; while (Date.now() < end) { const v = await page2.evaluate((k) => (window.__pippop || {})[k] ?? null, k).catch(() => null); if (v !== null) return v; await page2.waitForTimeout(500); } return null; };
console.log("login at", await until2("login", 900000));
await page2.waitForTimeout(2500);
await page2.mouse.click(1035, 477);                // Ya tengo cuenta
await page2.waitForTimeout(1500);
await page2.keyboard.type(EMAIL);
await page2.keyboard.press("Tab");
await page2.keyboard.type(PASS);
await page2.screenshot({ path: `${out}/w8-have.png` });
const keys = count(/device key issued/g);
await page2.keyboard.press("Enter");
await page2.waitForTimeout(12000);
await page2.screenshot({ path: `${out}/w9-have-in.png` });
check(count(/device key issued/g) === keys + 1, "Ya tengo cuenta: in with the password, a device key issued");
await browser.close();
server.close();
process.exit(fails.length ? 1 : 0);
