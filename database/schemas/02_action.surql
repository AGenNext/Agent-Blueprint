-- ============================================================
-- AGENT BLUEPRINT — Action Table
-- schema.org alignment: schema:Action
-- ============================================================

DEFINE TABLE IF NOT EXISTS action SCHEMAFULL
  PERMISSIONS
    FOR select WHERE $auth.id IS NOT NONE
    FOR create, update WHERE $auth.role IN ["orchestrator", "worker", "admin"]
    FOR delete WHERE $auth.role = "admin";

-- schema:Action core fields
DEFINE FIELD IF NOT EXISTS id             ON action TYPE record<action>;
DEFINE FIELD IF NOT EXISTS name           ON action TYPE string
  ASSERT $value != NONE AND string::len($value) > 0;
DEFINE FIELD IF NOT EXISTS description    ON action TYPE option<string>;

-- Action type (mirrors schema.org Action subtypes)
DEFINE FIELD IF NOT EXISTS action_type    ON action TYPE string
  ASSERT $value IN [
    "CreateAction", "UpdateAction", "DeleteAction", "ReadAction",
    "SearchAction", "SendAction", "ReceiveAction", "ExecuteAction",
    "PayAction", "ReviewAction", "CheckAction", "ScheduleAction"
  ]
  DEFAULT "ExecuteAction";

-- Agent relations
DEFINE FIELD IF NOT EXISTS agent_id       ON action TYPE record<agent>;
DEFINE FIELD IF NOT EXISTS assigned_by    ON action TYPE option<record<agent>>;
DEFINE FIELD IF NOT EXISTS delegated_to   ON action TYPE option<record<agent>>;

-- Lifecycle (schema:ActionStatusType)
DEFINE FIELD IF NOT EXISTS status         ON action TYPE string
  ASSERT $value IN [
    "PotentialActionStatus", "ActiveActionStatus",
    "CompletedActionStatus", "FailedActionStatus"
  ]
  DEFAULT "PotentialActionStatus";

-- Input / output objects (schema:EntryPoint / Result)
DEFINE FIELD IF NOT EXISTS input          ON action TYPE option<object>;
DEFINE FIELD IF NOT EXISTS result         ON action TYPE option<object>;
DEFINE FIELD IF NOT EXISTS error          ON action TYPE option<object>;

-- Time primitives (schema:startTime / endTime)
DEFINE FIELD IF NOT EXISTS scheduled_at   ON action TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS started_at     ON action TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS completed_at   ON action TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS created_at     ON action TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at     ON action TYPE datetime DEFAULT time::now();

-- Place (schema:location) — where the action executes
DEFINE FIELD IF NOT EXISTS location       ON action TYPE option<object>;

-- A2A protocol: parent task / sub-task graph
DEFINE FIELD IF NOT EXISTS parent_action  ON action TYPE option<record<action>>;
DEFINE FIELD IF NOT EXISTS priority       ON action TYPE int DEFAULT 5
  ASSERT $value >= 1 AND $value <= 10;

-- Metadata
DEFINE FIELD IF NOT EXISTS metadata       ON action TYPE option<object>;

-- Indexes
DEFINE INDEX IF NOT EXISTS idx_action_agent   ON action COLUMNS agent_id;
DEFINE INDEX IF NOT EXISTS idx_action_status  ON action COLUMNS status;
DEFINE INDEX IF NOT EXISTS idx_action_parent  ON action COLUMNS parent_action;
DEFINE INDEX IF NOT EXISTS idx_action_created ON action COLUMNS created_at;
