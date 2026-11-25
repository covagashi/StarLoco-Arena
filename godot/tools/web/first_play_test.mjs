// S53: the first play as a new player, on the web build — the sprint's
// closing check. Serves <web dir> on 127.0.0.1:8091 (as fight_load_test.mjs
// does), presses JUGAR (a demo account) in a W×H window and walks it: the
// boss, Aldebrán's intro read through, the tutorial's spotlight on Historia
// (a click outside it must do nothing), Reclutar in tutorial mode, back to
// the lobby, the tile again → Nilo's practice (RESIZE=1: the window goes to
// 1920×1080 and back mid-fight), leave it, the result, «¡Ya sabes pelear!».
// One capture per step in <out dir>, with the URL (it must stay on the game:
// before S53 the dialogs' history walked it to about:blank) and the open
// windows.
//
//   PLAYWRIGHT=<path to playwright/index.mjs> [RESIZE=1] node godot/tools/web/first_play_test.mjs \
//       <web dir> <ws url> <out dir> [W H]
//
// Needs a game server with ws_addr and limits.demo_accounts on (a local one:
// oracle-2 caps demo accounts per address and hour).

const [dir, ws, out, wArg, hArg] = process.argv.slice(2);
const W = Number(wArg || 1280), H = Number(hArg || 720), K = Math.min(W / 1280, H / 720);
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
const page = await browser.newPage({ viewport: { width: W, height: H } });
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
await page.mouse.click(1035 * K + (W - 1280 * K) / 2, 430 * K + (H - 720 * K) / 2);   // JUGAR
console.log("creation at", await until("creation", 180000));
// S53: the first play as a new player, on the web build — the closing check
const at = (x, y) => [x * K + (W - 1280 * K) / 2, y * K + (H - 720 * K) / 2];
const click = (x, y) => page.mouse.click(...at(x, y));
let n = 0;
const step = async (name) => { n++; await shot(`${String(n).padStart(2, "0")}-${name}`); console.log("shot", name, page.url(), JSON.stringify(await gui())); };
page.on("framenavigated", (f) => { if (f === page.mainFrame()) console.log("[nav]", f.url()); });
page.on("crash", () => console.log("[crash]"));
page.on("pageerror", (e) => console.log("[pageerror]", String(e).slice(0, 300)));
await page.waitForTimeout(3000);
await step("creation");
await click(1120, 485);                       // ¡CREAR!
await page.waitForTimeout(8000);
await step("intro");
for (let k = 0; k < 40; k++) { const g = await gui(); if (g && g.open.includes("npcTalkDialog")) break; await page.waitForTimeout(500); }
console.log("before intro len", await page.evaluate(() => history.length));
for (let i = 0; i < 14; i++) {                 // read Aldebrán's intro through
	const g = await gui();
	if (!g || !g.open.includes("npcTalkDialog")) break;
	await click(1106, 654);                       // Siguiente / Cerrar, at the plate's corner
	await page.waitForTimeout(700);
}
await page.waitForTimeout(1500);
await step("tutorial-recruit");
await click(40, 400);                         // outside the hole: nothing must open
await page.waitForTimeout(1200);
await step("click-outside");
await click(980, 230);                        // the Historia tile, inside the hole
await page.waitForTimeout(3500);
await step("recruit-screen");
await click(435, 666);
await page.keyboard.type("Primero");
await click(700, 666);                        // ¡RECLUTAR!
await page.waitForTimeout(6000);
await step("tutorial-fight");
await click(980, 230);                        // the tile: Nilo's practice
await page.waitForTimeout(20000);
await step("practice");
if (process.env.RESIZE) {
	await page.setViewportSize({ width: 1920, height: 1080 });
	await page.waitForTimeout(2500);
	await shot(`${String(++n).padStart(2, "0")}-practice-1920`);
	await page.setViewportSize({ width: W, height: H });
	await page.waitForTimeout(2500);
}
await page.keyboard.press("Space");           // Listo
await page.waitForTimeout(8000);
await step("practice-turn");
await page.mouse.click(...at(1245, 34));      // leave ⇥
await page.waitForTimeout(1500);
await page.keyboard.press("Enter");
await page.waitForTimeout(12000);
await step("after-fight");
await page.keyboard.press("Escape");          // the result
await page.waitForTimeout(3000);
await step("done");
await browser.close();
server.close();
process.exit(0);
