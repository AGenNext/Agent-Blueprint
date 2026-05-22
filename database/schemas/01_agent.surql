-- ============================================================
-- AGENT BLUEPRINT — Agent Identity Table
-- schema.org alignment: schema:SoftwareAgent + schema:Person
-- ============================================================

-- Agent: the universal agent identity record
DEFINE TABLE IF NOT EXISTS agent SCHEMAFULL
  PERMISSIONS
    FOR select WHERE $auth.id IS NOT NONE
    FOR create, update WHERE $auth.role IN ["orchestrator", "admin"]
    FOR delete WHERE $auth.role = "admin";

-- Core identity (schema:Thing)
DEFINE FIELD IF NOT EXISTS id           ON agent TYPE record<agent>;
DEFINE FIELD IF NOT EXISTS name         ON agent TYPE string
  ASSERT $value != NONE AND string::len($value) > 0;
DEFINE FIELD IF NOT EXISTS description  ON agent TYPE option<string>;
DEFINE FIELD IF NOT EXISTS url          ON agent TYPE option<string>;

-- Agent type (schema:SoftwareAgent | human | organization)
DEFINE FIELD IF NOT EXISTS agent_type   ON agent TYPE string
  ASSERT $value IN ["software", "human", "organization", "system"]
  DEFAULT "software";

-- DID / Decentralized Identity (W3C DID 1.1)
DEFINE FIELD IF NOT EXISTS did          ON agent TYPE option<string>;
DEFINE FIELD IF NOT EXISTS did_document ON agent TYPE option<object>;

-- Capability declarations (schema:knowsAbout / Action types)
DEFINE FIELD IF NOT EXISTS capabilities ON agent TYPE option<array<string>>;

-- Trust / role
DEFINE FIELD IF NOT EXISTS role         ON agent TYPE string
  ASSERT $value IN ["orchestrator", "worker", "observer", "admin"]
  DEFAULT "worker";
DEFINE FIELD IF NOT EXISTS trust_level  ON agent TYPE int
  ASSERT $value >= 0 AND $value <= 10
  DEFAULT 5;

-- Status lifecycle
DEFINE FIELD IF NOT EXISTS status       ON agent TYPE string
  ASSERT $value IN ["active", "suspended", "deprovisioned", "pending"]
  DEFAULT "pending";

-- Place (schema:Place) — where the agent is deployed
DEFINE FIELD IF NOT EXISTS location     ON agent TYPE option<object>;
  -- { country: "IN", region: "ap-south-1", datacenter: "aws-mumbai" }

-- Time primitives
DEFINE FIELD IF NOT EXISTS created_at   ON agent TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at   ON agent TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS last_seen_at ON agent TYPE option<datetime>;

-- Metadata / extensions (schema.org additionalProperty)
DEFINE FIELD IF NOT EXISTS metadata     ON agent TYPE option<object>;

-- Indexes
DEFINE INDEX IF NOT EXISTS idx_agent_did    ON agent COLUMNS did UNIQUE;
DEFINE INDEX IF NOT EXISTS idx_agent_status ON agent COLUMNS status;
DEFINE INDEX IF NOT EXISTS idx_agent_role   ON agent COLUMNS role;
