#!/usr/bin/env node
// node src/import-ads.js <Meta-Ad-Library/ads.json> --mac-root "<that folder on the Mac>"
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { importAds, save } from './ads.js';

const args = process.argv.slice(2);
const opt = (f) => (args.includes(f) ? args[args.indexOf(f) + 1] : null);
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const data = importAds(args[0], opt('--mac-root'));
save(join(ROOT, 'data/ads-library.json'), data);
const by = data.ads.reduce((m, a) => ((m[a.advertiser] = (m[a.advertiser] || 0) + 1), m), {});
console.log(`ads: ${data.ads.length} from ${Object.keys(by).length} advertisers, ${data.ads.filter((a) => a.status === 'active').length} active`);
