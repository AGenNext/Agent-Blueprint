-- ============================================================
-- AGENT BLUEPRINT — A2A Message Table
-- Agent-to-Agent communication protocol
-- schema.org alignment: schema:Message / schema:CommunicateAction
-- ============================================================

DEFINE TABLE IF NOT EXISTS message SCHEMAFULL
  PERMISSIONS
    FOR select WHERE $auth.id IS NOT NONE
      AND ($auth.id = sender OR $auth.id = recipient OR $auth.role = "orchestrator")
    FOR create WHERE $auth.id IS NOT NONE
    FOR update WHERE $auth.role = "admin"
    FOR delete WHERE $auth.role = "admin";

-- schema:Message core
DEFINE FIELD IF NOT EXISTS id            ON message TYPE record<message>;
DEFINE FIELD IF NOT EXISTS sender        ON message TYPE record<agent>;
DEFINE FIELD IF NOT EXISTS recipient     ON message TYPE record<agent>;
DEFINE FIELD IF NOT EXISTS thread_id     ON message TYPE option<string>;

-- Message type / protocol
DEFINE FIELD IF NOT EXISTS msg_type      ON message TYPE string
  ASSERT $value IN [
    "task_request", "task_result", "task_cancel",
    "capability_query", "capability_response",
    "heartbeat", "ack", "nack",
    "payment_request", "payment_ack",
    "policy_query", "policy_response",
    "data_request", "data_response",
    "error"
  ]
  DEFAULT "task_request";

-- Payload
DEFINE FIELD IF NOT EXISTS subject       ON message TYPE option<string>;
DEFINE FIELD IF NOT EXISTS body          ON message TYPE option<object>;
DEFINE FIELD IF NOT EXISTS attachments   ON message TYPE option<array<object>>;

-- Delivery state
DEFINE FIELD IF NOT EXISTS status        ON message TYPE string
  ASSERT $value IN ["pending", "delivered", "read", "failed", "expired"]
  DEFAULT "pending";

-- Time primitives
DEFINE FIELD IF NOT EXISTS sent_at       ON message TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS delivered_at  ON message TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS expires_at    ON message TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS ttl_seconds   ON message TYPE option<int>;

-- Linked action / event
DEFINE FIELD IF NOT EXISTS action_id     ON message TYPE option<record<action>>;
DEFINE FIELD IF NOT EXISTS trace_id      ON message TYPE option<string>;

-- Metadata
DEFINE FIELD IF NOT EXISTS metadata      ON message TYPE option<object>;

-- Indexes
DEFINE INDEX IF NOT EXISTS idx_msg_sender     ON message COLUMNS sender;
DEFINE INDEX IF NOT EXISTS idx_msg_recipient  ON message COLUMNS recipient;
DEFINE INDEX IF NOT EXISTS idx_msg_thread     ON message COLUMNS thread_id;
DEFINE INDEX IF NOT EXISTS idx_msg_status     ON message COLUMNS status;
DEFINE INDEX IF NOT EXISTS idx_msg_sent       ON message COLUMNS sent_at;
