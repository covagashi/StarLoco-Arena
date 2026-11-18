// S47: how long the web demo takes to load, and how much memory it holds.
//
//   PLAYWRIGHT=<path to playwright/index.mjs> node godot/tools/web/load_test.mjs \
//       <web dir> <ws url> <out dir> [label]
//
// Serves <web dir> (an export + tools/web/pack_web.gd) on 127.0.0.1:8090
// with gzip, as Caddy does in front of the demo (the bundles are zips
// already and go as they are), then for each network profile opens a fresh
// Chromium (no cache): times the engine (index.wasm) and the boot bundle
// (the first load: the login screen), and the bytes that crossed the wire.
// On the fast profile it then presses JUGAR (demo account) and waits for
// "Crea tu jefe", where the 3D coach stands, and reads the memory of the
// browser's processes (PSS, as S44 measured). Prints one JSON line per
// profile and saves a screenshot of each step in <out dir>.
// Needs a game server with ws_addr and limits.demo_accounts on.

import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { gzipSync } from "node:zlib";
import { extname, join } from "node:path";
const { chromium } = await import(process.env.PLAYWRIGHT || "playwright");

const [dir, ws, out, label = "build"] = process.argv.slice(2);
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
await new Promise((ok) => server.listen(Number(process.env.PORT || 8090), "127.0.0.1", ok));

// Chrome DevTools throughput is bytes per second.
const PROFILES = [
	{ name: "4G", down: (9 * 1e6) / 8, up: (3 * 1e6) / 8, latency: 60 },
	{ name: "fibra", down: (100 * 1e6) / 8, up: (50 * 1e6) / 8, latency: 10 },
];

// The browser's processes: everything under this node process, without
// node itself (Playwright's launch gives no browser pid).
function browserPss() {
	return pss(process.pid) - pss(process.pid, false)
}

function pss(pid, deep = true) {
	// the process and, deep, every process under it
	const kids = new Map();
	for (const p of readdirSync("/proc").filter((x) => /^\d+$/.test(x))) {
		try {
			const ppid = Number(readFileSync(`/proc/${p}/stat`, "utf8").split(") ")[1].split(" ")[1]);
			if (!kids.has(ppid)) kids.set(ppid, []);
			kids.get(ppid).push(Number(p));
		} catch {}
	}
	let total = 0;
	const todo = [pid];
	while (todo.length) {
		const p = todo.pop();
		try {
			const m = readFileSync(`/proc/${p}/smaps_rollup`, "utf8").match(/^Pss:\s+(\d+)/m);
			if (m) total += Number(m[1]);
		} catch {}
		if (deep) todo.push(...(kids.get(p) || []));
	}
	return Math.round(total / 1024);
}

for (const prof of PROFILES) {
	// the full Chromium in its new headless mode: the default headless shell
	// has no GPU and drew the game in software (3.8 fps)
	const browser = await chromium.launch({ channel: "chromium", args: ["--no-sandbox", "--use-angle=vulkan",
		"--enable-unsafe-webgpu", "--ignore-gpu-blocklist", "--enable-gpu-rasterization"] });
	const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
	const cdp = await page.context().newCDPSession(page);
	await cdp.send("Network.enable");
	await cdp.send("Network.emulateNetworkConditions", { offline: false, latency: prof.latency,
		downloadThroughput: prof.down, uploadThroughput: prof.up });
	const urls = new Map();
	let wire = 0;
	const done = {};
	cdp.on("Network.requestWillBeSent", (e) => urls.set(e.requestId, e.request.url));
	const t0 = Date.now();
	// the login is up (the boot bundle downloaded AND unpacked) when the
	// game marks it: login_screen.gd _mark → window.__pippop.login (ms since
	// the page started)
	const mark = (k) => page.evaluate((k) => (window.__pippop || {})[k] ?? null, k).catch(() => null);
	cdp.on("Network.loadingFinished", (e) => {
		wire += e.encodedDataLength;
		const u = urls.get(e.requestId) || "";
		const name = u.split("/").pop().split("?")[0];
		done[name] = (Date.now() - t0) / 1000;
	});
	await page.goto(`http://127.0.0.1:${process.env.PORT || 8090}/index.html?server=${encodeURIComponent(ws)}`);
	const manifest = JSON.parse(readFileSync(join(dir, "bundles/manifest.json"), "utf8"));
	const bootParts = manifest.boot.parts.map((p) => p.url.split("/").pop());
	const deadline = Date.now() + 600000;
	let tMain = null;
	while (tMain === null && Date.now() < deadline) {
		await page.waitForTimeout(500);
		const ms = await mark("login");
		if (ms !== null) tMain = +(ms / 1000).toFixed(1);
	}
	const firstWire = wire;
	const tBoot = Math.max(...bootParts.map((p) => done[p] ?? NaN));
	await page.waitForTimeout(3000);
	await page.screenshot({ path: join(out, `${label}-${prof.name}-login.png`), timeout: 120000 });
	const gpu = await page.evaluate(() => {
		const g = document.createElement("canvas").getContext("webgl2");
		const d = g && g.getExtension("WEBGL_debug_renderer_info");
		return d ? g.getParameter(d.UNMASKED_RENDERER_WEBGL) : "?";
	}).catch(() => "?");
	const row = { build: label, net: prof.name, gpu, wasm_s: done["index.wasm"], boot_s: tBoot, login_s: tMain,
		first_load_mb: +(firstWire / 1e6).toFixed(1) };
	if (prof.name === "fibra") {
		row.pss_login_mb = browserPss();
		// JUGAR, the login's big button (web: demo account)
		await page.mouse.click(1035, 430);
		let tc = null;
		const until = Date.now() + 120000;
		while (tc === null && Date.now() < until) {
			await page.waitForTimeout(500);
			tc = await mark("creation");
		}
		row.creation_after_login_s = tc === null ? null : +((tc / 1000) - tMain).toFixed(1);
		await page.waitForTimeout(5000);
		await page.screenshot({ path: join(out, `${label}-${prof.name}-creation.png`), timeout: 120000 });
		row.pss_creation_mb = browserPss();
		// frames the page draws in 4 s with the 3D coach on screen
		row.fps_creation = await page.evaluate(() => new Promise((ok) => {
			let n = 0;
			const t = performance.now();
			const tick = () => (performance.now() - t < 4000 ? (n++, requestAnimationFrame(tick)) : ok(+(n / 4).toFixed(1)));
			requestAnimationFrame(tick);
		}));
	}
	console.log(JSON.stringify(row));
	await browser.close();
}
server.close();
