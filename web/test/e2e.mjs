// Walks the funnel in a phone-sized Chromium against test/dev-server.mjs and
// saves a screenshot of every screen.
//
//   node test/dev-server.mjs &   then   node test/e2e.mjs [lang] [outDir]

import { chromium, devices } from "playwright";
import { mkdirSync } from "node:fs";

const base = process.env.BASE || "http://localhost:8788";
const lang = process.argv[2] || "en";
const out = process.argv[3] || "screens";
mkdirSync(out, { recursive: true });

const browser = await chromium.launch();
const context = await browser.newContext({ ...devices["Pixel 7"], locale: lang === "en" ? "en-US" : lang });
const page = await context.newPage();
const errors = [];
page.on("pageerror", (e) => errors.push(e.message));
page.on("console", (m) => { if (m.type() === "error" && !/fonts\.g|net::ERR/.test(m.text())) errors.push(m.text()); });

let n = 0;
const shot = async (name) => {
  await page.waitForTimeout(350);
  await page.screenshot({ path: `${out}/${String(++n).padStart(2, "0")}-${lang}-${name}.png`, fullPage: true });
};
const click = (selector) => page.locator(selector).first().click();
const footerBtn = () => page.locator(".footer .btn-primary").first().click();

await page.goto(`${base}/get/?a=tt03&lang=${lang}`);
await page.waitForSelector("#android");
await shot("bio");
await click("#android");

await page.waitForURL(/\/android\//);
await page.goto(`${base}/android/?fakeauth=1&ref=tt03&lang=${lang}`);
await page.waitForSelector(".screen");
await shot("welcome");
await footerBtn();
await shot("mechanism");
await footerBtn();
await shot("prayers");
await page.locator(".pill").nth(1).click(); // just fajr
await page.locator(".option").nth(4).click(); // + isha
await shot("prayers-selected");
await footerBtn();
await page.locator(".option").nth(3).click();
await page.locator(".option").nth(0).click();
await shot("goals");
await footerBtn();
await page.locator(".option").nth(1).click();
await shot("pace");
await footerBtn();
await shot("loading");
await page.waitForSelector(".summary", { timeout: 5000 });
await shot("plan");
await footerBtn();
await shot("account");
await page.locator(".google-btn").click();
await page.waitForSelector(".plans");
await shot("paywall");
await page.locator(".plan").nth(1).click();
await shot("paywall-monthly");
await page.locator("#checkout").click();
await page.waitForURL(/mock-checkout/);
await page.locator("#pay").click();
await page.waitForURL(/\/android\/welcome\//);
await page.waitForSelector(".success-mark", { timeout: 15000 });
await shot("welcome-paid");

await page.goto(`${base}/android/install/`);
await page.waitForSelector(".guide");
await shot("install");

console.log(JSON.stringify({ lang, screens: n, errors }, null, 2));
await browser.close();
if (errors.length) process.exit(1);
