// alfa-pippop.covaga.dev — the Pippop Arena web demo for friends (S44).
// Passes every request (the page, its bundles and the game's WebSocket on
// /ws) to the test server, so its address never shows; the player's own IP
// rides in X-Pippop-Client for the server's per-address limits.
// A name, not the address: Cloudflare refuses a Worker fetch to a bare IP
// (error 1003). sslip.io answers that name with the address in it.
const ORIGIN = "https://140-238-172-196.sslip.io";

export default {
  async fetch(request) {
    const url = new URL(request.url);
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
