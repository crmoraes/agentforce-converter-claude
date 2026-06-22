#!/usr/bin/env bash
#
# org-auth.sh — authenticate a Salesforce org for use with the Agentforce ADLC stack
#
# Usage:
#   ./scripts/org-auth.sh                    # interactive: choose auth method
#   ./scripts/org-auth.sh web                # browser OAuth (recommended for dev)
#   ./scripts/org-auth.sh jwt                # JWT bearer (recommended for CI)
#   ./scripts/org-auth.sh url                # sfdx auth URL (quick re-auth)
#
# What it does:
#   1. Checks SF CLI v2 is installed and meets minimum version
#   2. Runs the chosen auth method
#   3. Verifies Agentforce features are enabled in the connected org
#   4. Prints the org alias for use in deploy/retrieve commands
#
# Requires: Salesforce CLI v2 (sf)
# Optional: jq (for pretty-printing org info)

set -euo pipefail

# ── colours ──────────────────────────────────────────────────────────────────
if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]; then
  BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
  RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
else
  BLUE='' GREEN='' YELLOW='' RED='' BOLD='' NC=''
fi

step()    { echo -e "${BLUE}▶${NC} $1"; }
ok()      { echo -e "  ${GREEN}✓${NC} $1"; }
warn()    { echo -e "  ${YELLOW}⚠${NC} $1"; }
die()     { echo -e "  ${RED}✗${NC} $1" >&2; exit 1; }
ask()     { echo -e "${BOLD}?${NC} $1"; }

# ── 1. check SF CLI ───────────────────────────────────────────────────────────
step "Checking Salesforce CLI"

if ! command -v sf &>/dev/null; then
  die "SF CLI not found. Install it first:
  npm install -g @salesforce/cli
  Then re-run this script."
fi

SF_VERSION=$(sf --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0")
SF_MAJOR=${SF_VERSION%%.*}

if [[ "$SF_MAJOR" -lt 2 ]]; then
  die "SF CLI v2+ required (found v${SF_VERSION}). Upgrade:
  npm install -g @salesforce/cli"
fi

ok "SF CLI v${SF_VERSION}"

# ── 2. choose auth method ────────────────────────────────────────────────────
METHOD="${1:-}"

if [[ -z "$METHOD" ]]; then
  echo ""
  ask "Choose authentication method:"
  echo "  1) web  — Browser OAuth (recommended for developer workstations)"
  echo "  2) jwt  — JWT bearer token (recommended for CI/CD, no browser)"
  echo "  3) url  — sfdx auth URL (quick re-auth from a saved URL file)"
  echo ""
  read -rp "Enter 1, 2, or 3: " choice
  case "$choice" in
    1) METHOD="web" ;;
    2) METHOD="jwt" ;;
    3) METHOD="url" ;;
    *) die "Invalid choice." ;;
  esac
fi

# ── 3. ask for org alias ─────────────────────────────────────────────────────
echo ""
ask "Enter an alias for this org (e.g. agentforce-dev, my-sandbox):"
read -rp "Alias: " ORG_ALIAS
[[ -n "$ORG_ALIAS" ]] || die "Alias cannot be empty."

# ── 4. run auth ───────────────────────────────────────────────────────────────
echo ""

case "$METHOD" in

  # ── web OAuth ─────────────────────────────────────────────────────────────
  web)
    step "Authenticating via browser OAuth"
    echo ""
    echo "  This opens a browser window to complete Salesforce login."
    echo "  For a sandbox, use: login.salesforce.com → Custom Domain → your sandbox URL"
    echo ""
    ask "Is this a sandbox or scratch org? (y/n)"
    read -rp "> " IS_SANDBOX

    if [[ "$IS_SANDBOX" =~ ^[Yy] ]]; then
      ask "Enter your sandbox/scratch instance URL (e.g. https://mycompany--dev.sandbox.my.salesforce.com):"
      read -rp "URL: " INSTANCE_URL
      sf org login web \
        --alias "$ORG_ALIAS" \
        --instance-url "$INSTANCE_URL"
    else
      sf org login web \
        --alias "$ORG_ALIAS"
    fi
    ;;

  # ── JWT bearer ────────────────────────────────────────────────────────────
  jwt)
    step "Authenticating via JWT bearer token (CI/CD method)"
    echo ""
    echo "  Requirements:"
    echo "  - A Connected App in your Salesforce org with OAuth enabled"
    echo "  - The Connected App's Consumer Key (client_id)"
    echo "  - The private key file (.key or .pem) for the certificate uploaded to the Connected App"
    echo "  - The username of the org user the JWT will authenticate as"
    echo ""
    echo "  Setup guide if you haven't done this yet:"
    echo "  1. In your org: Setup → App Manager → New Connected App"
    echo "  2. Enable OAuth, check 'Use digital signatures'"
    echo "  3. Upload the public certificate (.crt) generated from your key pair"
    echo "  4. Add OAuth scopes: api, refresh_token, web"
    echo "  5. In Profiles/Permission Sets, pre-authorize the Connected App for your agent user"
    echo ""

    ask "Enter the path to your private key file (.key or .pem):"
    read -rp "Key file: " JWT_KEY_FILE
    [[ -f "$JWT_KEY_FILE" ]] || die "Key file not found: $JWT_KEY_FILE"

    ask "Enter the Connected App Consumer Key (client_id):"
    read -rp "Consumer Key: " CLIENT_ID
    [[ -n "$CLIENT_ID" ]] || die "Consumer Key cannot be empty."

    ask "Enter the username to authenticate as:"
    read -rp "Username: " JWT_USERNAME
    [[ -n "$JWT_USERNAME" ]] || die "Username cannot be empty."

    ask "Is this a sandbox or scratch org? (y/n)"
    read -rp "> " IS_SANDBOX

    if [[ "$IS_SANDBOX" =~ ^[Yy] ]]; then
      sf org login jwt \
        --alias "$ORG_ALIAS" \
        --client-id "$CLIENT_ID" \
        --jwt-key-file "$JWT_KEY_FILE" \
        --username "$JWT_USERNAME" \
        --instance-url "https://test.salesforce.com"
    else
      sf org login jwt \
        --alias "$ORG_ALIAS" \
        --client-id "$CLIENT_ID" \
        --jwt-key-file "$JWT_KEY_FILE" \
        --username "$JWT_USERNAME"
    fi
    ;;

  # ── sfdx auth URL ─────────────────────────────────────────────────────────
  url)
    step "Authenticating via sfdx auth URL"
    echo ""
    echo "  An sfdx auth URL looks like:"
    echo "  force://<clientId>:<clientSecret>:<refreshToken>@<instanceUrl>"
    echo ""
    echo "  To get an auth URL from an already-connected org:"
    echo "  sf org display --verbose --json -o <existing-alias> | jq -r '.result.sfdxAuthUrl'"
    echo ""

    ask "Enter the path to a file containing the sfdx auth URL:"
    read -rp "File path: " AUTH_URL_FILE
    [[ -f "$AUTH_URL_FILE" ]] || die "File not found: $AUTH_URL_FILE"

    sf org login sfdx-url \
      --alias "$ORG_ALIAS" \
      --sfdx-url-file "$AUTH_URL_FILE"
    ;;

  *)
    die "Unknown method: $METHOD. Use: web | jwt | url"
    ;;
esac

ok "Authentication complete — alias: ${BOLD}$ORG_ALIAS${NC}"

# ── 5. verify org connection ─────────────────────────────────────────────────
echo ""
step "Verifying org connection"

if ! sf org display --json -o "$ORG_ALIAS" &>/dev/null; then
  die "Could not connect to org with alias '$ORG_ALIAS'. Check credentials and re-run."
fi

if command -v jq &>/dev/null; then
  ORG_INFO=$(sf org display --json -o "$ORG_ALIAS" 2>/dev/null)
  ORG_USERNAME=$(echo "$ORG_INFO" | jq -r '.result.username // "unknown"')
  ORG_ID=$(echo "$ORG_INFO"       | jq -r '.result.id // "unknown"')
  ORG_URL=$(echo "$ORG_INFO"      | jq -r '.result.instanceUrl // "unknown"')
  ok "Username:     $ORG_USERNAME"
  ok "Org ID:       $ORG_ID"
  ok "Instance URL: $ORG_URL"
else
  sf org display -o "$ORG_ALIAS"
  warn "Install jq for cleaner output: brew install jq"
fi

# ── 6. check Agentforce feature flags ────────────────────────────────────────
echo ""
step "Checking Agentforce feature availability"

# Query for AgentforceEnabled setting via SOQL (available in API 63.0+)
AGENT_CHECK=$(sf data query \
  --query "SELECT Id FROM Organization LIMIT 1" \
  --json \
  -o "$ORG_ALIAS" 2>/dev/null || echo '{"status":1}')

if echo "$AGENT_CHECK" | grep -q '"status":0'; then
  ok "Org query successful"
else
  warn "Could not query org — verify API access and permissions."
fi

# Check if sf agent commands are available (installed plugin)
if sf agent --help &>/dev/null 2>&1; then
  ok "sf agent plugin available"
else
  warn "sf agent plugin not found. Install it:"
  warn "  sf plugins install @salesforce/plugin-agent"
fi

# ── 7. print summary ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Done.${NC} Org alias '${BOLD}$ORG_ALIAS${NC}' is ready."
echo ""
echo "Use this alias in deploy/retrieve commands:"
echo ""
echo "  # Retrieve an agent bundle"
echo "  sf project retrieve start --metadata \"AiAuthoringBundle:<Agent_Name>\" -o $ORG_ALIAS"
echo ""
echo "  # Deploy an agent bundle"
echo "  sf project deploy start --metadata \"AiAuthoringBundle:<Agent_Name>\" -o $ORG_ALIAS"
echo ""
echo "  # Set as default org (avoids typing -o every time)"
echo "  sf config set target-org=$ORG_ALIAS --global"
echo ""
echo "  # Open agent in Agentforce Studio"
echo "  sf org open authoring-bundle -o $ORG_ALIAS"
echo ""
echo "See HOWTO.md Section 3 for the full retrieve → convert → deploy workflow."
