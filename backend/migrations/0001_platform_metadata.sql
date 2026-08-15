CREATE TABLE IF NOT EXISTS platform_metadata (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS deployment_environments (
  environment TEXT PRIMARY KEY,
  release_id TEXT,
  database_schema_version TEXT,
  status TEXT NOT NULL DEFAULT 'unknown',
  deployed_at TEXT,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_deployment_environments_status
  ON deployment_environments(status, updated_at);
