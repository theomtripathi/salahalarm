const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const catalogs = ['Localizable', 'CoreLocalizable'];
const languages = ['ar', 'tr', 'id', 'ur'];
let count = 0;
const failures = [];
const placeholders = value => (value.replace(/%%/g, '').match(/%(?:\d+\$)?(?:[-+0 #]*\d*(?:\.\d+)?)(?:ll|l)?[@dfius]/g) || []).sort().join('|');
for (const table of catalogs) {
    const data = JSON.parse(fs.readFileSync(path.join(root, `Ramadan Pro/Resources/${table}.xcstrings`), 'utf8'));
    if (data.sourceLanguage !== 'en') failures.push(`${table}: wrong source language`);
    for (const [key, entry] of Object.entries(data.strings)) {
        count++;
        for (const language of languages) {
            const value = entry.localizations?.[language]?.stringUnit?.value;
            if (!value?.trim()) failures.push(`${table} / ${language}: missing ${key}`);
            else if (placeholders(key) !== placeholders(value)) failures.push(`${language}: placeholder mismatch ${key}`);
            if (language === 'ar' && /[پچژگٹڈڑںھہے]/u.test(value || '')) failures.push(`Arabic contains Urdu-specific letters: ${key}`);
        }
    }
}
if (failures.length) throw new Error(failures.join('\n'));
console.log(`PASS: ${count} catalog entries × ${languages.length} languages; placeholder parity and Arabic script checks`);
