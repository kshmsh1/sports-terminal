ALTER TABLE sso_login_states ADD COLUMN pkce_verifier_ciphertext TEXT;

CREATE TABLE IF NOT EXISTS sso_identities (
  connection_id TEXT NOT NULL REFERENCES sso_connections(id) ON DELETE CASCADE,
  provider_subject TEXT NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  organization_id TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  email_normalized TEXT NOT NULL,
  issuer TEXT NOT NULL,
  linked_at TEXT NOT NULL,
  last_login_at TEXT NOT NULL,
  PRIMARY KEY (connection_id, provider_subject),
  UNIQUE(connection_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_sso_identity_user
  ON sso_identities(user_id, organization_id);
CREATE INDEX IF NOT EXISTS idx_sso_identity_email
  ON sso_identities(organization_id, email_normalized);
