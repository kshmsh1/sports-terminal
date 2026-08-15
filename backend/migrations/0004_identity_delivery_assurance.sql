CREATE TABLE IF NOT EXISTS auth_delivery_tokens (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  purpose TEXT NOT NULL,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  attempts INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  consumed_at TEXT
);

CREATE TABLE IF NOT EXISTS auth_login_challenges (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  challenge_hash TEXT NOT NULL UNIQUE,
  factor_type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  attempts INTEGER NOT NULL DEFAULT 0,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  completed_at TEXT
);

CREATE TABLE IF NOT EXISTS auth_session_security (
  token_hash TEXT PRIMARY KEY REFERENCES auth_sessions(token_hash) ON DELETE CASCADE,
  auth_level TEXT NOT NULL DEFAULT 'password',
  mfa_verified_at TEXT,
  device_hash TEXT,
  client_hash TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS delivery_outbox (
  id TEXT PRIMARY KEY,
  channel TEXT NOT NULL,
  destination_hash TEXT NOT NULL,
  template_key TEXT NOT NULL,
  payload TEXT NOT NULL DEFAULT '{}',
  provider TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'queued',
  attempts INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  delivered_at TEXT,
  failed_at TEXT,
  error TEXT
);

CREATE INDEX IF NOT EXISTS idx_auth_delivery_tokens_user
  ON auth_delivery_tokens(user_id, purpose, status, expires_at);
CREATE INDEX IF NOT EXISTS idx_auth_login_challenges_user
  ON auth_login_challenges(user_id, status, expires_at);
CREATE INDEX IF NOT EXISTS idx_delivery_outbox_status
  ON delivery_outbox(status, created_at);
