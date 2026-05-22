#!/usr/bin/env bash
# ============================================================
# Agent Blueprint — Deploy to SurrealDB Cloud
# Run this FROM YOUR VPS (51.75.251.56) where IP is allowed
#
# Usage:
#   SURREAL_PASS=<your-pass> bash run.sh
#   SURREAL_PASS=<your-pass> bash run.sh --no-seed    # schema only
#   SURREAL_PASS=<your-pass> bash run.sh --dry-run    # validate only
# ============================================================

set -euo pipefail

SURREAL_URL="${SURREAL_URL:-wss://schemadb-06ehsj292ppah8kbsk9pmnjjbc.aws-aps1.surreal.cloud}"
SURREAL_USER="${SURREAL_USER:-root}"
SURREAL_NS="${SURREAL_NS:-autonomyx}"
SURREAL_DB="${SURREAL_DB:-agent_framework}"

if [ -z "${SURREAL_PASS:-}" ]; then
  echo "ERROR: SURREAL_PASS is required"
  echo "Usage: SURREAL_PASS=mypassword bash run.sh"
  exit 1
fi

# Install Python dep if missing
pip install surrealdb --break-system-packages -q 2>/dev/null || true

# Run deploy
export SURREAL_URL SURREAL_USER SURREAL_PASS SURREAL_NS SURREAL_DB

python3 "$(dirname "$0")/deploy.py" "$@"
