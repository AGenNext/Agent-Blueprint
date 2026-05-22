-- ============================================================
-- AGENT BLUEPRINT — Policy Decision Log
-- OPA (Open Policy Agent) integration audit table
-- schema.org alignment: schema:GovernanceDocument
-- ============================================================

DEFINE TABLE IF NOT EXISTS policy_decision SCHEMAFULL
  PERMISSIONS
    FOR select WHERE $auth.role IN ["orchestrator", "admin"]
    FOR create WHERE $auth.id IS NOT NONE
    FOR update, delete WHERE $auth.role = "admin";

DEFINE FIELD IF NOT EXISTS id              ON policy_decision TYPE record<policy_decision>;

-- The request that was evaluated
DEFINE FIELD IF NOT EXISTS requesting_agent ON policy_decision TYPE record<agent>;
DEFINE FIELD IF NOT EXISTS action_requested ON policy_decision TYPE string;
DEFINE FIELD IF NOT EXISTS resource         ON policy_decision TYPE string;

-- OPA evaluation
DEFINE FIELD IF NOT EXISTS policy_path      ON policy_decision TYPE string;
  -- e.g. "agent/authz/allow"
DEFINE FIELD IF NOT EXISTS opa_input        ON policy_decision TYPE object;
DEFINE FIELD IF NOT EXISTS opa_result       ON policy_decision TYPE object;
DEFINE FIELD IF NOT EXISTS decision         ON policy_decision TYPE string
  ASSERT $value IN ["allow", "deny", "error"]
  DEFAULT "deny";
DEFINE FIELD IF NOT EXISTS reason           ON policy_decision TYPE option<string>;

-- Timing
DEFINE FIELD IF NOT EXISTS evaluated_at     ON policy_decision TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS latency_ms       ON policy_decision TYPE option<int>;

-- Tracing
DEFINE FIELD IF NOT EXISTS trace_id         ON policy_decision TYPE option<string>;
DEFINE FIELD IF NOT EXISTS action_id        ON policy_decision TYPE option<record<action>>;

-- Indexes
DEFINE INDEX IF NOT EXISTS idx_pd_agent    ON policy_decision COLUMNS requesting_agent;
DEFINE INDEX IF NOT EXISTS idx_pd_decision ON policy_decision COLUMNS decision;
DEFINE INDEX IF NOT EXISTS idx_pd_time     ON policy_decision COLUMNS evaluated_at;
DEFINE INDEX IF NOT EXISTS idx_pd_trace    ON policy_decision COLUMNS trace_id;
