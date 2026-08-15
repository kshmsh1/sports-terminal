CREATE TABLE IF NOT EXISTS auth_email_verifications (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  consumed_at TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS auth_password_resets (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TEXT NOT NULL,
  consumed_at TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS auth_mfa_factors (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  factor_type TEXT NOT NULL,
  secret_ciphertext TEXT NOT NULL,
  label TEXT,
  verified_at TEXT,
  disabled_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS auth_recovery_codes (
  code_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  consumed_at TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS auth_security_events (
  id TEXT PRIMARY KEY,
  user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL,
  ip_hash TEXT,
  user_agent_hash TEXT,
  metadata TEXT NOT NULL DEFAULT '{}',
  recorded_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_email_verification_user
  ON auth_email_verifications(user_id, expires_at);
CREATE INDEX IF NOT EXISTS idx_password_reset_user
  ON auth_password_resets(user_id, expires_at);
CREATE INDEX IF NOT EXISTS idx_mfa_factor_user
  ON auth_mfa_factors(user_id, disabled_at);
CREATE INDEX IF NOT EXISTS idx_security_event_user
  ON auth_security_events(user_id, recorded_at);
