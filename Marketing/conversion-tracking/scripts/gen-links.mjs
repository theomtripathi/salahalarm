#!/usr/bin/env node
// Builds data/links.json (read by the worker) and data/links.csv (paste into the sheet)
// from data/accounts.json + data/videos.csv.  Usage: node scripts/gen-links.mjs
import { readFileSync, writeFileSync } from "node:fs";
import { buildLinks, parseCsv } from "../src/links.js";

const dir = new URL("../data/", import.meta.url);
const config = JSON.parse(readFileSync(new URL("accounts.json", dir), "utf8"));
const videos = parseCsv(readFileSync(new URL("videos.csv", dir), "utf8"));
const links = buildLinks(config, videos);

writeFileSync(new URL("links.json", dir), JSON.stringify(links, null, 2) + "\n");
const rows = [["short_link", "kind", "account", "platform", "format", "video", "ct", "app_store_url"]];
for (const [slug, l] of Object.entries(links)) {
  rows.push([`https://${config.domain}/go/${slug}`, l.kind, l.account, l.platform, l.format, l.video || "", l.ct, l.target]);
}
writeFileSync(new URL("links.csv", dir), rows.map((r) => r.join(",")).join("\n") + "\n");

if (config.providerToken.startsWith("REPLACE")) console.warn("warning: providerToken is still a placeholder");
console.log(`wrote ${Object.keys(links).length} links`);
