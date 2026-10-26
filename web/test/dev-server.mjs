// Local preview of the whole funnel without Cloudflare, Firebase or Dodo:
// serves public/, runs the real Worker against the in-memory backend from
// fakes.js, and fakes the Dodo checkout page.
//
//   node test/dev-server.mjs            http://localhost:8788/get/
//   COUNTRY=US node test/dev-server.mjs  pretend the visitor is in the US
//
// Pages use the localhost-only fake sign-in (open /android/?fakeauth=1).

import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { join, extname, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import worker from "../src/worker.js";
import { createBackend, env as testEnv, idToken } from "./fakes.js";

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "public");
const port = Number(process.env.PORT || 8788);
const backend = createBackend();
const realFetch = globalThis.fetch;
globalThis.fetch = async (url, init) => {
  const u = new URL(typeof url === "string" ? url : url.url);
  if (u.host.endsWith("posthog.com")) return new Response("{}");
  return backend.fetch(url, init);
};
void realFetch;

const apk = Buffer.alloc(11 * 1024 * 1024, 1);
const env = testEnv({
  PRICE_PREVIEW: process.env.PREVIEW ? "on" : "off",
  TRIAL_DAYS: process.env.TRIAL_DAYS || "{}",
  POSTHOG_KEY: "",
  APKS: {
    get: async (key) => key === "latest.json"
      ? { json: async () => ({ versionCode: 1, versionName: "1.0.0" }) }
      : key === "salahalarm-latest.apk" ? { body: new Blob([apk]).stream(), size: apk.length } : null,
    head: async () => ({ size: apk.length }),
  },
});
if (process.env.PREVIEW) backend.dodo.previewCurrency = { currency: "IDR", amount: 15900000 };

const TYPES = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".css": "text/css", ".png": "image/png", ".webp": "image/webp", ".json": "application/json", ".svg": "image/svg+xml" };

// The browser's fake sign-in sends "fake.<base64 user>.sig"; swap it for a signed test token.
function realToken(header) {
  const m = header?.match(/^Bearer fake\.([^.]+)\.sig$/);
  if (!m) return header;
  const u = JSON.parse(Buffer.from(m[1], "base64").toString());
  return `Bearer ${idToken({ uid: u.uid, email: u.email })}`;
}

createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${port}`);
  try {
    if (url.pathname === "/mock-checkout") {
      const session = backend.dodo.sessions.get(url.searchParams.get("session"));
      if (url.searchParams.get("pay")) {
        backend.pay(session.id);
        res.writeHead(302, { location: session.req.return_url.replace("https://salahalarm.com", "") + `&subscription_id=sub_${session.id}&status=active` });
        return res.end();
      }
      res.writeHead(200, { "content-type": "text/html" });
      return res.end(`<!doctype html><meta name=viewport content="width=device-width"><body style="font:16px system-ui;padding:24px">
        <h2>Dodo Payments (mock)</h2><p>${session.req.product_cart[0].product_id} for ${session.req.customer?.email}</p>
        <a id=pay href="/mock-checkout?session=${session.id}&pay=1" style="display:block;padding:16px;background:#111;color:#fff;text-align:center;border-radius:12px">Pay</a>
        <a id=cancel href="${session.req.cancel_url.replace("https://salahalarm.com", "")}" style="display:block;padding:16px;text-align:center">Back</a></body>`);
    }

    if (url.pathname.startsWith("/api/") || url.pathname.startsWith("/download/")) {
      const body = ["POST", "PUT"].includes(req.method) ? await new Promise((r) => { let d = ""; req.on("data", (c) => (d += c)); req.on("end", () => r(d)); }) : undefined;
      const headers = { ...req.headers };
      if (headers.authorization) headers.authorization = realToken(headers.authorization);
      const request = new Request(`https://salahalarm.com${url.pathname}${url.search}`, { method: req.method, headers, body });
      Object.defineProperty(request, "cf", {
        value: { country: process.env.COUNTRY || "ID", city: process.env.CITY || "Jakarta", timezone: process.env.TZ_NAME || "Asia/Jakarta", latitude: "-6.2088", longitude: "106.8456" },
      });
      const out = await worker.fetch(request, env, { waitUntil() {} });
      let text = Buffer.from(await out.arrayBuffer());
      if (url.pathname === "/api/checkout" && out.ok) {
        const json = JSON.parse(text);
        if (json.checkoutUrl) json.checkoutUrl = `/mock-checkout?session=${json.sessionId}`;
        text = Buffer.from(JSON.stringify(json));
      }
      res.writeHead(out.status, Object.fromEntries(out.headers));
      return res.end(req.method === "HEAD" ? undefined : text);
    }

    let path = join(root, decodeURIComponent(url.pathname));
    if (!path.startsWith(root)) throw new Error("bad path");
    if ((await stat(path).catch(() => null))?.isDirectory()) path = join(path, "index.html");
    const data = await readFile(path);
    res.writeHead(200, { "content-type": TYPES[extname(path)] || "application/octet-stream" });
    res.end(data);
  } catch (err) {
    res.writeHead(err.code === "ENOENT" ? 404 : 500, { "content-type": "text/plain" });
    res.end(String(err.message));
  }
}).listen(port, () => console.log(`funnel preview on http://localhost:${port}/get/`));
