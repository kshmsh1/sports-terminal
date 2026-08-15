CREATE TABLE IF NOT EXISTS organization_security_policies (
  organization_id TEXT PRIMARY KEY REFERENCES organizations(id) ON DELETE CASCADE,
  require_mfa INTEGER NOT NULL DEFAULT 0,
  sso_required INTEGER NOT NULL DEFAULT 0,
  max_session_days INTEGER NOT NULL DEFAULT 30,
  allowed_email_domains TEXT NOT NULL DEFAULT '[]',
  updated_by_user_id TEXT REFERENCES users(id),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sso_connections (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  connection_type TEXT NOT NULL,
  issuer TEXT NOT NULL,
  client_id TEXT NOT NULL,
  client_secret_ciphertext TEXT,
  authorization_endpoint TEXT,
  token_endpoint TEXT,
  jwks_uri TEXT,
  allowed_domains TEXT NOT NULL DEFAULT '[]',
  status TEXT NOT NULL DEFAULT 'disabled',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(organization_id, issuer, client_id)
);

CREATE TABLE IF NOT EXISTS sso_login_states (
  id TEXT PRIMARY KEY,
  connection_id TEXT NOT NULL REFERENCES sso_connections(id) ON DELETE CASCADE,
  state_hash TEXT NOT NULL UNIQUE,
  nonce_hash TEXT NOT NULL,
  redirect_uri TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  consumed_at TEXT,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sso_connections_org
  ON sso_connections(organization_id, status);
CREATE INDEX IF NOT EXISTS idx_sso_login_states_expiry
  ON sso_login_states(expires_at, consumed_at);
