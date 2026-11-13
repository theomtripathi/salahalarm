-- Salah Alarm Affiliates: accounts, link visits, attributed events, conversions, payouts.
CREATE TABLE IF NOT EXISTS affiliates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  username TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'active',          -- active | blocked
  payout_method TEXT,                              -- wise | paypal | payoneer
  payout_details TEXT,                             -- account email / id the affiliate entered
  username_changed INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  last_active_at TEXT,
  first_visit_at TEXT,
  first_install_at TEXT,
  payable_notified_at TEXT,
  note TEXT
);

-- Every username an affiliate has had keeps working (old links never break).
CREATE TABLE IF NOT EXISTS usernames (
  username TEXT PRIMARY KEY,
  affiliate_id INTEGER NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,
  affiliate_id INTEGER,                            -- NULL for admin sessions
  role TEXT NOT NULL,                              -- affiliate | admin
  expires_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS login_tokens (
  token_hash TEXT PRIMARY KEY,
  affiliate_id INTEGER NOT NULL,
  expires_at TEXT NOT NULL,
  used_at TEXT,
  created_at TEXT NOT NULL
);

-- One row per click on an affiliate link.
CREATE TABLE IF NOT EXISTS visits (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  affiliate_id INTEGER NOT NULL,
  visitor_id TEXT,
  ts TEXT NOT NULL,
  day TEXT NOT NULL,
  country TEXT,
  os TEXT,
  referrer TEXT,
  is_bot INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS visits_aff ON visits(affiliate_id, day);

-- app_user_id (Firebase uid) -> affiliate. First attribution wins.
CREATE TABLE IF NOT EXISTS attributions (
  app_user_id TEXT PRIMARY KEY,
  affiliate_id INTEGER NOT NULL,
  visitor_id TEXT,
  source TEXT NOT NULL,
  created_at TEXT NOT NULL
);

-- Funnel events from the onboarding site: checkout_started, store_redirect (= download).
CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  affiliate_id INTEGER NOT NULL,
  type TEXT NOT NULL,
  app_user_id TEXT,
  visitor_id TEXT,
  platform TEXT,
  plan TEXT,
  ts TEXT NOT NULL,
  dedupe_key TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS events_aff ON events(affiliate_id, type);

-- Every charge from an attributed customer. commission_usd is what the affiliate is owed for it.
-- status: pending (waiting for Om) | approved | rejected | refunded | no_commission
CREATE TABLE IF NOT EXISTS conversions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  affiliate_id INTEGER NOT NULL,
  external_id TEXT NOT NULL UNIQUE,
  source TEXT NOT NULL,                            -- dodo | revenuecat | manual
  kind TEXT NOT NULL,                              -- first | renewal | refund | adjustment
  app_user_id TEXT,
  platform TEXT,
  product_id TEXT,
  interval TEXT,                                   -- week | year | lifetime | unknown
  amount REAL NOT NULL,
  currency TEXT NOT NULL,
  amount_usd REAL NOT NULL,
  fx_estimated INTEGER NOT NULL DEFAULT 0,
  commission_usd REAL NOT NULL,
  rule TEXT,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  decided_at TEXT,
  payout_id INTEGER,
  note TEXT,
  raw TEXT
);
CREATE INDEX IF NOT EXISTS conv_aff ON conversions(affiliate_id, status);

CREATE TABLE IF NOT EXISTS payouts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  affiliate_id INTEGER NOT NULL,
  amount_usd REAL NOT NULL,
  method TEXT,
  reference TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS posts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  affiliate_id INTEGER NOT NULL,
  url TEXT NOT NULL,
  platform TEXT,
  content_type TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
