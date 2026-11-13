// Worker entry: routes every request into the AffiliatesStore Durable Object.
import { DurableObject } from 'cloudflare:workers';
import { app } from './worker.js';
import { migrate, sqlDb } from './do-db.js';

// Production storage: one SQLite-backed Durable Object holds the whole database, and
// every request runs inside it (env.DB is a D1-shaped adapter over its SQL storage).
// With a D1 binding (tests, local dev) requests run directly against D1.
export class AffiliatesStore extends DurableObject {
  constructor(state, env) {
    super(state, env);
    migrate(state.storage.sql);
    this.db = sqlDb(state.storage.sql);
  }

  async fetch(request) {
    return app(request, { ...this.env, DB: this.db }, this.ctx);
  }
}

export default {
  async fetch(request, env, ctx) {
    if (env.DB) return app(request, env, ctx);
    const country = request.cf?.country;
    const fwd = new Request(request);
    if (country && !fwd.headers.has('x-aff-country')) fwd.headers.set('x-aff-country', country);
    return env.STORE.get(env.STORE.idFromName('main')).fetch(fwd);
  },
};
