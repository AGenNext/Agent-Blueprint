#!/usr/bin/env python3
"""
Agent Blueprint — SurrealDB Sandbox Deploy
Applies all schemas in /database/schemas/*.surql in order.

Usage:
  SURREAL_URL=wss://...surreal.cloud \
  SURREAL_USER=root \
  SURREAL_PASS=<pass> \
  python3 deploy.py [--dry-run] [--reset]
"""

import asyncio
import os
import sys
import glob
import argparse
from pathlib import Path

try:
    from surrealdb import AsyncSurreal
except ImportError:
    print("ERROR: pip install surrealdb --break-system-packages")
    sys.exit(1)


SURREAL_URL  = os.environ.get("SURREAL_URL",  "wss://schemadb-06ehsj292ppah8kbsk9pmnjjbc.aws-aps1.surreal.cloud")
SURREAL_USER = os.environ.get("SURREAL_USER", "root")
SURREAL_PASS = os.environ.get("SURREAL_PASS", "")
SURREAL_NS   = os.environ.get("SURREAL_NS",   "autonomyx")
SURREAL_DB   = os.environ.get("SURREAL_DB",   "agent_framework")

SCHEMA_DIR   = Path(__file__).parent / "database" / "schemas"


async def connect():
    db = AsyncSurreal(SURREAL_URL)
    await db.connect()
    await db.signin({"username": SURREAL_USER, "password": SURREAL_PASS})
    await db.use(SURREAL_NS, SURREAL_DB)
    return db


async def apply_schema(db, path: Path, dry_run: bool = False):
    content = path.read_text()
    # Strip namespace/database switches — already selected via .use()
    lines = [
        l for l in content.splitlines()
        if not l.strip().upper().startswith("DEFINE NAMESPACE")
        and not l.strip().upper().startswith("DEFINE DATABASE")
        and not l.strip().upper().startswith("USE NS")
        and not l.strip().upper().startswith("USE DB")
    ]
    surql = "\n".join(lines).strip()

    print(f"  📄 {path.name} — {len(surql)} chars", end="")
    if dry_run:
        print(" [DRY RUN]")
        return True

    try:
        result = await db.query(surql)
        errors = [r for r in result if isinstance(r, dict) and r.get("status") == "ERR"]
        if errors:
            print(f" ❌ ERRORS: {errors}")
            return False
        print(" ✅")
        return True
    except Exception as e:
        print(f" ❌ EXCEPTION: {e}")
        return False


async def seed_demo_data(db):
    """Insert a minimal set of demo records to validate graph traversal."""
    print("\n🌱 Seeding demo data...")

    seed_surql = """
    -- Orchestrator agent
    CREATE agent:orchestrator CONTENT {
        name: "Autonomyx Orchestrator",
        description: "Primary orchestrator agent for Agent Blueprint",
        agent_type: "software",
        role: "orchestrator",
        trust_level: 10,
        status: "active",
        capabilities: ["delegate", "monitor", "schedule", "audit"],
        location: { country: "IN", region: "ap-south-1" },
        created_at: time::now(),
        updated_at: time::now()
    };

    -- Worker agent
    CREATE agent:worker_01 CONTENT {
        name: "Research Worker 01",
        description: "General-purpose research and retrieval agent",
        agent_type: "software",
        role: "worker",
        trust_level: 7,
        status: "active",
        capabilities: ["web_search", "summarise", "extract"],
        location: { country: "IN", region: "ap-south-1" },
        created_at: time::now(),
        updated_at: time::now()
    };

    -- Demo skill
    CREATE skill:web_search CONTENT {
        name: "Web Search",
        slug: "web-search",
        description: "Search the web and return structured results",
        version: "1.0.0",
        skill_type: "mcp_tool",
        action_type: "SearchAction",
        auth_required: true,
        status: "active",
        created_at: time::now(),
        updated_at: time::now()
    };

    -- Demo action
    CREATE action:demo_task_01 CONTENT {
        name: "Research Agent Blueprint patterns",
        action_type: "SearchAction",
        agent_id: agent:worker_01,
        assigned_by: agent:orchestrator,
        status: "PotentialActionStatus",
        priority: 7,
        input: { query: "SurrealDB schema.org agent framework 2026" },
        created_at: time::now(),
        updated_at: time::now()
    };

    -- Graph edges
    RELATE agent:orchestrator -> delegates_to -> agent:worker_01
        CONTENT { scope: ["SearchAction"], created_at: time::now() };

    RELATE agent:worker_01 -> has_skill -> skill:web_search
        CONTENT { proficiency: 8 };

    RELATE agent:orchestrator -> trusts -> agent:worker_01
        CONTENT { trust_level: 7, reason: "Verified capability set", created_at: time::now() };

    -- Demo event
    CREATE event:demo_evt_01 CONTENT {
        name: "Agent Blueprint sandbox initialised",
        event_type: "SystemAlert",
        source_agent: agent:orchestrator,
        severity: "info",
        payload: { message: "Schema applied successfully", version: "v1.0.0" },
        occurred_at: time::now()
    };

    -- Demo payment provider (sandbox)
    CREATE payment_provider:stripe_sandbox CONTENT {
        provider_name: "Stripe Sandbox",
        provider_type: "stripe",
        integration_mode: "sandbox",
        status: "active",
        created_at: time::now(),
        updated_at: time::now()
    };

    -- Demo payment intent: orchestrator pays worker
    CREATE payment_intent:demo_pi_01 CONTENT {
        payer_agent: agent:orchestrator,
        payee_agent: agent:worker_01,
        payment_mode: "agent_to_agent",
        service_type: "research_task",
        amount: 10.00dec,
        currency: "INR",
        status: "requested",
        idempotency_key: "demo-pi-001-20260522",
        created_by: agent:orchestrator,
        metadata: { description: "Payment for demo research task" },
        created_at: time::now(),
        updated_at: time::now()
    };

    -- Demo ledger entry (AP/AR)
    CREATE payment_ledger:demo_ledger_01 CONTENT {
        payment_intent_id: payment_intent:demo_pi_01,
        payer: agent:orchestrator,
        receiver: agent:worker_01,
        amount: 10.00dec,
        currency: "INR",
        payable_status: "payable_open",
        receivable_status: "receivable_open",
        delivery_status: "service_not_started",
        settlement_status: "not_started",
        reconciliation_status: "not_started",
        created_at: time::now(),
        updated_at: time::now()
    };

    -- Payment graph edges
    RELATE agent:orchestrator -> initiates_payment -> payment_intent:demo_pi_01
        CONTENT { initiated_at: time::now() };
    RELATE agent:worker_01 -> receives_payment -> payment_intent:demo_pi_01;
    """
    try:
        result = await db.query(seed_surql)
        errors = [r for r in result if isinstance(r, dict) and r.get("status") == "ERR"]
        if errors:
            print(f"  ⚠️  Seed errors (may be duplicates): {errors[:3]}")
        else:
            print("  ✅ Demo records inserted")
    except Exception as e:
        print(f"  ⚠️  Seed warning: {e}")


async def verify(db):
    """Run validation queries to confirm schema is live."""
    print("\n🔍 Verification queries...")

    checks = {
        "Agents":             "SELECT count() AS n FROM agent GROUP ALL",
        "Actions":            "SELECT count() AS n FROM action GROUP ALL",
        "Events":             "SELECT count() AS n FROM event GROUP ALL",
        "Skills":             "SELECT count() AS n FROM skill GROUP ALL",
        "Messages":           "SELECT count() AS n FROM message GROUP ALL",
        "Policy Decisions":   "SELECT count() AS n FROM policy_decision GROUP ALL",
        "Payment Intents":    "SELECT count() AS n FROM payment_intent GROUP ALL",
        "Payment Ledger":     "SELECT count() AS n FROM payment_ledger GROUP ALL",
        "Payment Providers":  "SELECT count() AS n FROM payment_provider GROUP ALL",
        "Graph: delegates":   "SELECT count() AS n FROM delegates_to GROUP ALL",
        "Graph: has_skill":   "SELECT count() AS n FROM has_skill GROUP ALL",
        "Graph: trusts":      "SELECT count() AS n FROM trusts GROUP ALL",
        "Graph: pay/receive": "SELECT count() AS n FROM initiates_payment GROUP ALL",
    }

    all_ok = True
    for label, surql in checks.items():
        try:
            r = await db.query(surql)
            count = r[0]["n"] if r and isinstance(r[0], dict) else "?"
            print(f"  {label:<22} → {count} records ✅")
        except Exception as e:
            print(f"  {label:<22} → ❌ {e}")
            all_ok = False

    # Graph traversal check
    try:
        r = await db.query(
            "SELECT name, ->delegates_to->agent.name AS delegates_to FROM agent WHERE id = agent:orchestrator"
        )
        print(f"\n  Graph traversal  → {r} ✅")
    except Exception as e:
        print(f"\n  Graph traversal  → ❌ {e}")
        all_ok = False

    return all_ok


async def main():
    parser = argparse.ArgumentParser(description="Agent Blueprint — SurrealDB Deploy")
    parser.add_argument("--dry-run", action="store_true", help="Parse schemas without applying")
    parser.add_argument("--no-seed", action="store_true", help="Skip demo data seeding")
    parser.add_argument("--no-verify", action="store_true", help="Skip verification pass")
    args = parser.parse_args()

    print("=" * 60)
    print("  Agent Blueprint — SurrealDB Sandbox Deploy")
    print(f"  Target : {SURREAL_URL}")
    print(f"  NS/DB  : {SURREAL_NS} / {SURREAL_DB}")
    print("=" * 60)

    # Discover schema files
    schema_files = sorted(SCHEMA_DIR.glob("*.surql"))
    if not schema_files:
        print(f"ERROR: No .surql files found in {SCHEMA_DIR}")
        sys.exit(1)

    print(f"\n📁 Found {len(schema_files)} schema files:")
    for f in schema_files:
        print(f"   {f.name}")

    if args.dry_run:
        print("\n⚠️  DRY RUN — no changes will be applied\n")

    # Connect
    print("\n🔌 Connecting to SurrealDB...")
    try:
        db = await connect()
        print(f"  ✅ Connected as {SURREAL_USER} → {SURREAL_NS}/{SURREAL_DB}")
    except Exception as e:
        print(f"  ❌ Connection failed: {e}")
        sys.exit(1)

    # Apply schemas in order
    print("\n📐 Applying schemas...")
    failed = []
    for schema_file in schema_files:
        ok = await apply_schema(db, schema_file, dry_run=args.dry_run)
        if not ok:
            failed.append(schema_file.name)

    if failed:
        print(f"\n❌ {len(failed)} schema(s) failed: {failed}")
        await db.close()
        sys.exit(1)

    print(f"\n✅ All {len(schema_files)} schemas applied")

    # Seed demo data
    if not args.no_seed and not args.dry_run:
        await seed_demo_data(db)

    # Verify
    if not args.no_verify and not args.dry_run:
        ok = await verify(db)
        if not ok:
            print("\n⚠️  Verification had issues — check above")
        else:
            print("\n🎉 Sandbox fully operational")

    await db.close()

    print("\n" + "=" * 60)
    print("  Connection string for your apps:")
    print(f"  URL  : {SURREAL_URL}")
    print(f"  NS   : {SURREAL_NS}")
    print(f"  DB   : {SURREAL_DB}")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
