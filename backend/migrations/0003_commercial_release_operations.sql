CREATE TABLE IF NOT EXISTS billing_customers (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL,
  provider_customer_id TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS billing_webhook_events (
  provider_event_id TEXT PRIMARY KEY,
  provider TEXT NOT NULL,
  event_type TEXT NOT NULL,
  payload_sha256 TEXT NOT NULL,
  received_at TEXT NOT NULL,
  processed_at TEXT,
  status TEXT NOT NULL DEFAULT 'received',
  error TEXT
);

CREATE TABLE IF NOT EXISTS entitlement_grants (
  id TEXT PRIMARY KEY,
  subject_type TEXT NOT NULL,
  subject_id TEXT NOT NULL,
  entitlement_key TEXT NOT NULL,
  source TEXT NOT NULL,
  starts_at TEXT,
  ends_at TEXT,
  revoked_at TEXT,
  metadata TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(subject_type, subject_id, entitlement_key, source)
);

CREATE TABLE IF NOT EXISTS certified_releases (
  id TEXT PRIMARY KEY,
  league TEXT NOT NULL,
  season TEXT NOT NULL,
  release_version TEXT NOT NULL,
  manifest_sha256 TEXT NOT NULL,
  manifest_json TEXT NOT NULL,
  signature TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'candidate',
  source_snapshot TEXT,
  certified_at TEXT,
  activated_at TEXT,
  retired_at TEXT,
  created_at TEXT NOT NULL,
  UNIQUE(league, season, release_version)
);

CREATE TABLE IF NOT EXISTS release_activations (
  id TEXT PRIMARY KEY,
  environment TEXT NOT NULL,
  release_id TEXT NOT NULL REFERENCES certified_releases(id),
  previous_release_id TEXT REFERENCES certified_releases(id),
  actor TEXT NOT NULL,
  reason TEXT,
  activated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS platform_audit_events (
  id TEXT PRIMARY KEY,
  actor_type TEXT NOT NULL,
  actor_id TEXT,
  action TEXT NOT NULL,
  object_type TEXT,
  object_id TEXT,
  request_id TEXT,
  metadata TEXT NOT NULL DEFAULT '{}',
  previous_event_sha256 TEXT,
  event_sha256 TEXT NOT NULL,
  recorded_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS backup_manifests (
  id TEXT PRIMARY KEY,
  database_backend TEXT NOT NULL,
  schema_version TEXT NOT NULL,
  release_id TEXT,
  object_key TEXT NOT NULL,
  byte_size INTEGER,
  sha256 TEXT NOT NULL,
  signature TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'created',
  created_at TEXT NOT NULL,
  verified_at TEXT,
  restored_at TEXT
);

CREATE TABLE IF NOT EXISTS rate_limit_buckets (
  bucket_key TEXT PRIMARY KEY,
  window_started_at INTEGER NOT NULL,
  request_count INTEGER NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_billing_events_status
  ON billing_webhook_events(status, received_at);
CREATE INDEX IF NOT EXISTS idx_entitlements_subject
  ON entitlement_grants(subject_type, subject_id, entitlement_key);
CREATE INDEX IF NOT EXISTS idx_certified_releases_scope
  ON certified_releases(league, season, status, created_at);
CREATE INDEX IF NOT EXISTS idx_release_activations_environment
  ON release_activations(environment, activated_at);
CREATE INDEX IF NOT EXISTS idx_platform_audit_recorded
  ON platform_audit_events(recorded_at, action);
CREATE INDEX IF NOT EXISTS idx_backup_manifests_created
  ON backup_manifests(created_at, status);
CREATE INDEX IF NOT EXISTS idx_rate_limit_updated
  ON rate_limit_buckets(updated_at);
