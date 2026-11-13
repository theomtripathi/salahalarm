// D1-shaped adapter over a SQLite-backed Durable Object (ctx.storage.sql), so the
// same queries run on D1 (tests, local) and in the Durable Object (production).
import schema from './schema.js';

export function migrate(sql) {
  for (const stmt of splitSql(schema)) sql.exec(stmt);
}

export function splitSql(text) {
  return text
    .split('\n').filter((l) => !l.trim().startsWith('--')).join('\n')
    .split(';').map((s) => s.trim()).filter(Boolean);
}

export function sqlDb(sql) {
  const stmt = (query, args = []) => ({
    bind: (...a) => stmt(query, a),
    async first() { return sql.exec(query, ...args).toArray()[0] ?? null; },
    async all() { return { results: sql.exec(query, ...args).toArray() }; },
    async run() {
      const cur = sql.exec(query, ...args);
      cur.toArray();
      return { meta: { changes: cur.rowsWritten } };
    },
  });
  return {
    prepare: (query) => stmt(query),
    async batch(list) { const out = []; for (const s of list) out.push(await s.run()); return out; },
  };
}
