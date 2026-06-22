#!/usr/bin/env bash
#
# retrieve-legacy-agent.sh — retrieve legacy Agentforce metadata from an org and
# assemble it into the Shape A planner JSON that the agentforce-to-agent-script
# conversion skill expects.
#
# Usage:
#   ./scripts/retrieve-legacy-agent.sh <agent-api-name> [-o <org-alias>]
#
# Examples:
#   ./scripts/retrieve-legacy-agent.sh Agentforce_Service_Agent -o my-dev-org
#   ./scripts/retrieve-legacy-agent.sh Agentforce_Service_Agent   # uses default org
#
# What it does:
#   1. Retrieves GenAiPlugin:*, GenAiFunction:* and Bot:<name> metadata from the org
#   2. Calls assemble_legacy_agent.py to parse the XML and build Shape A JSON
#   3. Writes the JSON to legacy/<agent-api-name>.json
#
# Output: legacy/<agent-api-name>.json  — ready to feed to the conversion skill:
#   "Use the agentforce-to-agent-script skill to convert legacy/<name>.json"
#
# Requires: sf CLI v2, python3, the org already authenticated (run ./scripts/org-auth.sh first)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── colours ──────────────────────────────────────────────────────────────────
if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]; then
  BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
  RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
else
  BLUE='' GREEN='' YELLOW='' RED='' BOLD='' NC=''
fi

step()  { echo -e "${BLUE}▶${NC} $1"; }
ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
die()   { echo -e "  ${RED}✗${NC} $1" >&2; exit 1; }

# ── args ──────────────────────────────────────────────────────────────────────
AGENT_NAME="${1:-}"
ORG_FLAG=""

if [[ -z "$AGENT_NAME" ]]; then
  echo "Usage: $0 <agent-api-name> [-o <org-alias>]"
  echo ""
  echo "  <agent-api-name>  The DeveloperName (API name) of the legacy Agentforce agent."
  echo "                    Find it in Setup → Agents, or via:"
  echo "                    sf data query --use-tooling-api \\"
  echo "                      --query \"SELECT DeveloperName FROM GenAiPlugin LIMIT 20\" \\"
  echo "                      -o <org-alias>"
  echo ""
  exit 1
fi

shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--target-org) ORG_FLAG="-o $2"; shift 2 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

# ── sanity checks ─────────────────────────────────────────────────────────────
command -v sf &>/dev/null   || die "SF CLI not found. Run: npm install -g @salesforce/cli"
command -v python3 &>/dev/null || die "python3 not found."

[[ -f "$SCRIPT_DIR/assemble_legacy_agent.py" ]] \
  || die "assemble_legacy_agent.py not found at $SCRIPT_DIR/"

[[ -f "$ROOT/sfdx-project.json" ]] \
  || die "sfdx-project.json not found at repo root. Are you in the right directory?"

echo -e "${BOLD}Agentforce legacy retrieve: ${AGENT_NAME}${NC}"
echo ""

# ── 1. discover plugin / function names for this agent ───────────────────────
step "Discovering plugins and functions for '${AGENT_NAME}'"

# Query the Tooling API to find GenAiPlugin records linked to this agent name.
# GenAiPlugin names in legacy Agentforce follow the pattern: <Topic>_<BotId>
# We use a LIKE filter on the MasterLabel and DeveloperName to find candidates.
# The user can also pass the exact plugin API name pattern if the default is wrong.

PLUGIN_QUERY="SELECT DeveloperName, MasterLabel FROM GenAiPlugin LIMIT 200"
PLUGINS_JSON=$(sf data query \
  --use-tooling-api \
  --query "$PLUGIN_QUERY" \
  --json \
  $ORG_FLAG 2>/dev/null || echo '{"status":1}')

if echo "$PLUGINS_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('status')==0 else 1)" 2>/dev/null; then
  PLUGIN_COUNT=$(echo "$PLUGINS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['totalSize'])")
  ok "Found ${PLUGIN_COUNT} GenAiPlugin record(s) in org"
else
  warn "Could not query Tooling API — will retrieve all GenAiPlugin:* and filter locally."
  PLUGINS_JSON='{"status":0,"result":{"records":[]}}'
  PLUGIN_COUNT=0
fi

FUNC_QUERY="SELECT DeveloperName, MasterLabel FROM GenAiFunction LIMIT 500"
FUNCS_JSON=$(sf data query \
  --use-tooling-api \
  --query "$FUNC_QUERY" \
  --json \
  $ORG_FLAG 2>/dev/null || echo '{"status":0,"result":{"records":[]}}')

# ── 2. retrieve metadata XML ──────────────────────────────────────────────────
step "Retrieving GenAiPlugin and GenAiFunction metadata XML"

# Build metadata spec: retrieve all plugins and functions (we filter by agent in step 3)
METADATA_SPEC="GenAiPlugin:* GenAiFunction:*"

# Also try to retrieve the Bot metadata for agent-level fields
BOT_META="Bot:${AGENT_NAME}_Bot"

sf project retrieve start \
  --metadata "$METADATA_SPEC" \
  --json \
  $ORG_FLAG \
  2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('status') == 0:
    files = d.get('result', {}).get('files', [])
    for f in files:
        print(f\"  retrieved: {f.get('filePath','')}\")
" || true

# Retrieve Bot metadata (best-effort; may not exist for all legacy agent types)
sf project retrieve start \
  --metadata "$BOT_META" \
  --json \
  $ORG_FLAG \
  2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('status') == 0:
    files = d.get('result', {}).get('files', [])
    for f in files:
        print(f\"  retrieved: {f.get('filePath','')}\")
" || warn "Bot metadata not found for '${AGENT_NAME}_Bot' — agent-level fields will use defaults."

ok "Metadata retrieve complete"

# ── 3. assemble Shape A JSON ──────────────────────────────────────────────────
step "Assembling Shape A JSON from retrieved XML"

mkdir -p "$ROOT/legacy"
OUTPUT_FILE="$ROOT/legacy/${AGENT_NAME}.json"

python3 "$SCRIPT_DIR/assemble_legacy_agent.py" \
  --source-dir "$ROOT/force-app/main/default" \
  --agent-name "$AGENT_NAME" \
  --output "$OUTPUT_FILE" \
  --tooling-plugins "$PLUGINS_JSON" \
  --tooling-functions "$FUNCS_JSON"

# ── 4. summary ────────────────────────────────────────────────────────────────
echo ""
ok "Output: ${BOLD}${OUTPUT_FILE}${NC}"
echo ""
echo "Next — feed the JSON to the conversion skill:"
echo ""
echo "  \"Use the agentforce-to-agent-script skill to convert legacy/${AGENT_NAME}.json\""
echo ""
echo "Or via the full ADLC pipeline:"
echo ""
echo "  \"Use adlc-orchestrator to convert, deploy, and test legacy/${AGENT_NAME}.json\""
echo ""
echo "Review ${OUTPUT_FILE} before converting — fields marked '# TODO:' need manual input."
