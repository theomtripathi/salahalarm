// Builds app/src/main/assets/i18n.json for the Android app.
//
// Keys are the English strings. Translations come from the iOS string catalogs
// first (so both apps say the same thing), then web/i18n/web.json, then
// android/i18n/android.json for strings only the Android app has.
//
//   node scripts/build-i18n.mjs          build
//   node scripts/build-i18n.mjs --check  also fail if a t()/tf() string has no translation

import { readFileSync, writeFileSync, readdirSync, statSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const repo = join(root, "..");
const LANGS = ["ar", "tr", "id", "ur"];

function catalog(file) {
  const out = {};
  const { strings } = JSON.parse(readFileSync(file, "utf8"));
  for (const [key, entry] of Object.entries(strings)) {
    for (const lang of LANGS) {
      const value = entry.localizations?.[lang]?.stringUnit?.value;
      if (value) (out[lang] ||= {})[key] = value;
    }
  }
  return out;
}

function walk(dir) {
  return readdirSync(dir).flatMap((name) => {
    const p = join(dir, name);
    return statSync(p).isDirectory() ? walk(p) : [p];
  });
}

const unescape = (s) => JSON.parse(`"${s.replace(/\\\$/g, "$")}"`);

const sources = [join(root, "app/src/main/kotlin"), join(root, "core/src/main/kotlin")]
  .flatMap(walk)
  .filter((f) => f.endsWith(".kt") && !f.endsWith("Duas.kt"));

const keys = new Set();
const called = new Set();
for (const file of sources) {
  const src = readFileSync(file, "utf8");
  for (const m of src.matchAll(/"((?:[^"\\\n]|\\.)*)"/g)) {
    try {
      keys.add(unescape(m[1]));
    } catch {
      /* not a plain string */
    }
  }
  for (const m of src.matchAll(/\bt[f]?\(\s*"((?:[^"\\\n]|\\.)*)"/g)) called.add(unescape(m[1]));
}

const ios = [
  catalog(join(repo, "Ramadan Pro/Resources/Localizable.xcstrings")),
  catalog(join(repo, "Ramadan Pro/Resources/CoreLocalizable.xcstrings")),
];
const web = JSON.parse(readFileSync(join(repo, "web/i18n/web.json"), "utf8"));
const android = JSON.parse(readFileSync(join(root, "i18n/android.json"), "utf8"));
for (const key of Object.keys(android.en || {})) keys.add(key);

const out = {};
const missing = new Map();
for (const lang of LANGS) {
  out[lang] = {};
  for (const key of keys) {
    const value = android[lang]?.[key] ?? ios[0][lang]?.[key] ?? ios[1][lang]?.[key] ?? web[lang]?.[key];
    if (value) out[lang][key] = value;
    else if (called.has(key) && /[A-Za-z]/.test(key)) (missing.get(key) || missing.set(key, []).get(key)).push(lang);
  }
}

mkdirSync(join(root, "app/src/main/assets"), { recursive: true });
writeFileSync(join(root, "app/src/main/assets/i18n.json"), JSON.stringify(out));
console.log(`i18n.json written (${LANGS.map((l) => `${l} ${Object.keys(out[l]).length}`).join(", ")})`);
if (missing.size) {
  console.log(`\n${missing.size} UI strings without a translation:`);
  for (const [key, langs] of missing) console.log(`  ${JSON.stringify(key)}  [${langs.join(",")}]`);
  if (process.argv.includes("--check")) process.exit(1);
}
