-- ============================================================
-- AGENT BLUEPRINT — Graph Edges (RELATE tables)
-- SurrealDB native graph: RELATE agent -> ... -> agent/skill/action
-- ============================================================

-- ── agent -> delegates_to -> agent ──────────────────────────
DEFINE TABLE IF NOT EXISTS delegates_to SCHEMAFULL TYPE RELATION IN agent OUT agent
  PERMISSIONS
    FOR select WHERE $auth.id IS NOT NONE
    FOR create, update WHERE $auth.role IN ["orchestrator", "admin"]
    FOR delete WHERE $auth.role = "admin";

DEFINE FIELD IF NOT EXISTS scope        ON delegates_to TYPE option<array<string>>;
DEFINE FIELD IF NOT EXISTS expires_at   ON delegates_to TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS created_at   ON delegates_to TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS granted_by   ON delegates_to TYPE option<record<agent>>;

-- ── agent -> has_skill -> skill ──────────────────────────────
DEFINE TABLE IF NOT EXISTS has_skill SCHEMAFULL TYPE RELATION IN agent OUT skill
  PERMISSIONS
    FOR select WHERE $auth.id IS NOT NONE
    FOR create, update WHERE $auth.role IN ["orchestrator", "admin"]
    FOR delete WHERE $auth.role = "admin";

DEFINE FIELD IF NOT EXISTS proficiency  ON has_skill TYPE int DEFAULT 5
  ASSERT $value >= 1 AND $value <= 10;
DEFINE FIELD IF NOT EXISTS certified_at ON has_skill TYPE option<datetime>;

-- ── agent -> performs -> action ──────────────────────────────
DEFINE TABLE IF NOT EXISTS performs SCHEMAFULL TYPE RELATION IN agent OUT action
  PERMISSIONS
    FOR select WHERE $auth.id IS NOT NONE
    FOR create WHERE $auth.id IS NOT NONE
    FOR update, delete WHERE $auth.role = "admin";

DEFINE FIELD IF NOT EXISTS started_at   ON performs TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS ended_at     ON performs TYPE option<datetime>;

-- ── action -> triggers -> event ──────────────────────────────
DEFINE TABLE IF NOT EXISTS triggers SCHEMAFULL TYPE RELATION IN action OUT event
  PERMISSIONS
    FOR select WHERE $auth.id IS NOT NONE
    FOR create WHERE $auth.id IS NOT NONE
    FOR update, delete WHERE $auth.role = "admin";

DEFINE FIELD IF NOT EXISTS triggered_at ON triggers TYPE datetime DEFAULT time::now();

-- ── agent -> trusts -> agent ─────────────────────────────────
DEFINE TABLE IF NOT EXISTS trusts SCHEMAFULL TYPE RELATION IN agent OUT agent
  PERMISSIONS
    FOR select WHERE $auth.id IS NOT NONE
    FOR create, update WHERE $auth.role IN ["orchestrator", "admin"]
    FOR delete WHERE $auth.role = "admin";

DEFINE FIELD IF NOT EXISTS trust_level  ON trusts TYPE int DEFAULT 5
  ASSERT $value >= 0 AND $value <= 10;
DEFINE FIELD IF NOT EXISTS reason       ON trusts TYPE option<string>;
DEFINE FIELD IF NOT EXISTS created_at   ON trusts TYPE datetime DEFAULT time::now();
