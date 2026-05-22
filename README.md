# Agent Blueprint

**Universal agent framework** — SurrealDB as native graph engine, schema.org as type system,
time+place as first-class primitives, A2A messaging, OPA policy integration, DID identity.

> Part of the AGenNext platform. Infrastructure-level, not vertical SaaS.

---

## Schema Overview

| File | Table(s) | schema.org Alignment |
|------|----------|----------------------|
| `01_agent.surql` | `agent` | `schema:SoftwareAgent`, `schema:Person` |
| `02_action.surql` | `action` | `schema:Action` + subtypes |
| `03_event.surql` | `event` | `schema:Event` |
| `04_policy_decision.surql` | `policy_decision` | OPA audit log |
| `05_message.surql` | `message` | `schema:Message`, A2A protocol |
| `06_skill.surql` | `skill` | `schema:HowTo`, `schema:SoftwareApplication` |
| `07_edges.surql` | `delegates_to`, `has_skill`, `performs`, `triggers`, `trusts` | Graph relations |

## Deploy to SurrealDB Cloud (from VPS)

```bash
# Upload this folder to VPS first
scp -r ./agent-blueprint root@51.75.251.56:/root/

# SSH in and run
ssh root@51.75.251.56
cd /root/agent-blueprint
SURREAL_PASS=<your-password> bash run.sh
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SURREAL_URL` | `wss://schemadb-06ehsj292ppah8kbsk9pmnjjbc.aws-aps1.surreal.cloud` | Cloud endpoint |
| `SURREAL_USER` | `root` | SurrealDB username |
| `SURREAL_PASS` | *(required)* | SurrealDB password |
| `SURREAL_NS` | `autonomyx` | Namespace |
| `SURREAL_DB` | `agent_framework` | Database |

## Verify (after deploy)

Open Surrealist at https://surrealist.app → Connect → paste your cloud URL.

Then run:

```surql
-- Check tables
INFO FOR DB;

-- Count records
SELECT count() AS n FROM agent GROUP ALL;

-- Graph traversal: who does orchestrator delegate to?
SELECT name, ->delegates_to->agent.name AS delegates_to
FROM agent WHERE id = agent:orchestrator;

-- Full agent list
SELECT id, name, role, status, trust_level FROM agent;
```

## Architecture

```
schema.org primitives
    ↓
SurrealDB (graph + document + relational)
    ├── agent          ← identity, DID, role, trust
    ├── action         ← task lifecycle (schema:Action)
    ├── event          ← audit trail, telemetry
    ├── message        ← A2A communication
    ├── skill          ← capability registry
    ├── policy_decision ← OPA evaluation log
    └── edges          ← delegates_to, has_skill, performs, triggers, trusts
```

## Roadmap

- [ ] `payment_intent` table (from Agent-Pay repo)
- [ ] `did_document` full W3C DID 1.1 resolution
- [ ] SurrealDB LIVE SELECT for real-time A2A delivery
- [ ] OPA sidecar function (fn::opa_check)
- [ ] Python SDK (`agent_blueprint` pip package)
- [ ] FastAPI REST layer
- [ ] Coolify one-click deploy
