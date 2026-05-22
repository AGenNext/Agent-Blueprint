-- ============================================================
-- AGENT BLUEPRINT — Event Table
-- schema.org alignment: schema:Event
-- ============================================================

DEFINE TABLE IF NOT EXISTS event SCHEMAFULL
  PERMISSIONS
    FOR select WHERE $auth.id IS NOT NONE
    FOR create WHERE $auth.role IN ["orchestrator", "worker", "system", "admin"]
    FOR update, delete WHERE $auth.role = "admin";

-- schema:Event core
DEFINE FIELD IF NOT EXISTS id             ON event TYPE record<event>;
DEFINE FIELD IF NOT EXISTS name           ON event TYPE string;
DEFINE FIELD IF NOT EXISTS description    ON event TYPE option<string>;

-- Event classification
DEFINE FIELD IF NOT EXISTS event_type     ON event TYPE string
  ASSERT $value IN [
    "AgentStarted", "AgentStopped", "AgentProvisioned", "AgentDeprovisioned",
    "ActionStarted", "ActionCompleted", "ActionFailed", "ActionDelegated",
    "PaymentInitiated", "PaymentCompleted", "PaymentFailed",
    "PolicyEvaluated", "PolicyDenied",
    "IdentityAsserted", "IdentityRevoked",
    "MessageSent", "MessageReceived",
    "SkillInvoked", "SkillCompleted",
    "SystemAlert", "AuditEvent"
  ];

-- Who emitted this event
DEFINE FIELD IF NOT EXISTS source_agent   ON event TYPE option<record<agent>>;
DEFINE FIELD IF NOT EXISTS source_action  ON event TYPE option<record<action>>;

-- Who is the subject
DEFINE FIELD IF NOT EXISTS subject_type   ON event TYPE option<string>;
DEFINE FIELD IF NOT EXISTS subject_id     ON event TYPE option<string>;

-- Time primitives (schema:startDate / endDate)
DEFINE FIELD IF NOT EXISTS occurred_at    ON event TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS duration_ms    ON event TYPE option<int>;

-- Place (schema:location)
DEFINE FIELD IF NOT EXISTS location       ON event TYPE option<object>;
  -- { country: "IN", region: "ap-south-1", ip: "...", datacenter: "..." }

-- Payload / context
DEFINE FIELD IF NOT EXISTS payload        ON event TYPE option<object>;
DEFINE FIELD IF NOT EXISTS severity       ON event TYPE string
  ASSERT $value IN ["debug", "info", "warn", "error", "critical"]
  DEFAULT "info";

-- Correlation (for tracing across actions/events)
DEFINE FIELD IF NOT EXISTS trace_id       ON event TYPE option<string>;
DEFINE FIELD IF NOT EXISTS span_id        ON event TYPE option<string>;

-- Metadata
DEFINE FIELD IF NOT EXISTS metadata       ON event TYPE option<object>;

-- Indexes
DEFINE INDEX IF NOT EXISTS idx_event_type     ON event COLUMNS event_type;
DEFINE INDEX IF NOT EXISTS idx_event_occurred ON event COLUMNS occurred_at;
DEFINE INDEX IF NOT EXISTS idx_event_source   ON event COLUMNS source_agent;
DEFINE INDEX IF NOT EXISTS idx_event_trace    ON event COLUMNS trace_id;
DEFINE INDEX IF NOT EXISTS idx_event_severity ON event COLUMNS severity;
