// Read and write seo/data/keywords.csv. CommonJS so shell one-liners can require it.
const fs = require('node:fs');
const path = require('node:path');

const FILE = path.join(__dirname, '..', 'data', 'keywords.csv');

function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = '';
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') {
        field += '"';
        i++;
      } else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') {
      row.push(field);
      field = '';
    } else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(field);
      if (row.length > 1 || row[0] !== '') rows.push(row);
      row = [];
      field = '';
    } else field += c;
  }
  if (field !== '' || row.length) {
    row.push(field);
    rows.push(row);
  }
  return rows;
}

const cell = (v) => {
  const s = v == null ? '' : String(v);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

function readKeywords(file = FILE) {
  const [header, ...rows] = parseCsv(fs.readFileSync(file, 'utf8'));
  const list = rows.map((r) => Object.fromEntries(header.map((h, i) => [h, r[i] ?? ''])));
  list.columns = header;
  return list;
}

function writeKeywords(list, file = FILE) {
  const header = list.columns;
  const lines = [header.join(','), ...list.map((r) => header.map((h) => cell(r[h])).join(','))];
  fs.writeFileSync(file, lines.join('\n') + '\n');
}

module.exports = { readKeywords, writeKeywords, parseCsv, FILE };
