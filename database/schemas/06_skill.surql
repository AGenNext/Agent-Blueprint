-- ============================================================
-- AGENT BLUEPRINT — Skill Registry
-- schema.org alignment: schema:HowTo / schema:SoftwareApplication
-- ============================================================

DEFINE TABLE IF NOT EXISTS skill SCHEMAFULL
  PERMISSIONS
    FOR select WHERE $auth.id IS NOT NONE
    FOR create, update WHERE $auth.role IN ["orchestrator", "admin"]
    FOR delete WHERE $auth.role = "admin";

DEFINE FIELD IF NOT EXISTS id            ON skill TYPE record<skill>;
DEFINE FIELD IF NOT EXISTS name          ON skill TYPE string
  ASSERT string::len($value) > 0;
DEFINE FIELD IF NOT EXISTS slug          ON skill TYPE string
  ASSERT string::len($value) > 0;
DEFINE FIELD IF NOT EXISTS description   ON skill TYPE option<string>;
DEFINE FIELD IF NOT EXISTS version       ON skill TYPE string DEFAULT "1.0.0";

-- Skill type
DEFINE FIELD IF NOT EXISTS skill_type    ON skill TYPE string
  ASSERT $value IN ["function", "agent", "workflow", "api", "mcp_tool"]
  DEFAULT "function";

-- Schema.org action type this skill implements
DEFINE FIELD IF NOT EXISTS action_type   ON skill TYPE option<string>;

-- Input/output schema (JSON Schema compatible)
DEFINE FIELD IF NOT EXISTS input_schema  ON skill TYPE option<object>;
DEFINE FIELD IF NOT EXISTS output_schema ON skill TYPE option<object>;

-- Invocation
DEFINE FIELD IF NOT EXISTS endpoint      ON skill TYPE option<string>;
DEFINE FIELD IF NOT EXISTS auth_required ON skill TYPE bool DEFAULT true;

-- Status
DEFINE FIELD IF NOT EXISTS status        ON skill TYPE string
  ASSERT $value IN ["active", "deprecated", "experimental"]
  DEFAULT "active";

-- Owner
DEFINE FIELD IF NOT EXISTS owner_agent   ON skill TYPE option<record<agent>>;

-- Time
DEFINE FIELD IF NOT EXISTS created_at    ON skill TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at    ON skill TYPE datetime DEFAULT time::now();

-- Metadata
DEFINE FIELD IF NOT EXISTS metadata      ON skill TYPE option<object>;

-- Indexes
DEFINE INDEX IF NOT EXISTS idx_skill_slug   ON skill COLUMNS slug UNIQUE;
DEFINE INDEX IF NOT EXISTS idx_skill_type   ON skill COLUMNS skill_type;
DEFINE INDEX IF NOT EXISTS idx_skill_status ON skill COLUMNS status;
