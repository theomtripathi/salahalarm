// Minimal D1 stand-in on node:sqlite, enough for the Worker's queries in tests.
import { DatabaseSync } from 'node:sqlite';
import schema from '../src/schema.js';

export function makeDb() {
  const db = new DatabaseSync(':memory:');
  db.exec(schema);
  const stmt = (sql, args = []) => ({
    bind: (...a) => stmt(sql, a),
    async first() { return db.prepare(sql).get(...args) ?? null; },
    async all() { return { results: db.prepare(sql).all(...args) }; },
    async run() { const r = db.prepare(sql).run(...args); return { meta: { changes: Number(r.changes), last_row_id: Number(r.lastInsertRowid) } }; },
  });
  return {
    raw: db,
    prepare: (sql) => stmt(sql),
    async batch(list) { const out = []; for (const s of list) out.push(await s.run()); return out; },
  };
}
