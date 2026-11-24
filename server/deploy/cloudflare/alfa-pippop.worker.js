// alfa-pippop.covaga.dev — the Pippop Arena game server's public name (S44).
// Passes the game's WebSocket on /ws to the test server, so its address
// never shows; the player's own IP rides in X-Pippop-Client for the
// server's per-address limits.
// S51: the game is played on itch.io only. Once ITCH holds the page's
// address, every other path answers a redirect there; while it is empty the
// Worker still passes the page and its bundles through.
// A name, not the address: Cloudflare refuses a Worker fetch to a bare IP
// (error 1003). sslip.io answers that name with the address in it.
const ORIGIN = "https://140-238-172-196.sslip.io";
const ITCH = "";

export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (ITCH && url.pathname !== "/ws") {
      return Response.redirect(ITCH, 302);
    }
    const headers = new Headers(request.headers);
    headers.set("X-Pippop-Client", request.headers.get("CF-Connecting-IP") || "");
    headers.delete("Host");
    return fetch(ORIGIN + url.pathname + url.search, {
      method: request.method,
      headers,
      body: ["GET", "HEAD"].includes(request.method) ? undefined : request.body,
      redirect: "manual",
    });
  },
};
