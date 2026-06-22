#!/usr/bin/env bash
#
# install.sh — install the full Agentforce ADLC stack into ~/.claude/
#
# What this installs:
#   Local (from this repo):
#     skills/agentforce-to-agent-script  → ~/.claude/skills/
#     agents/*                           → ~/.claude/agents/
#
#   Upstream (from SalesforceAIResearch/agentforce-adlc):
#     skills/developing-agentforce       → ~/.claude/skills/
#     skills/testing-agentforce          → ~/.claude/skills/
#     skills/observing-agentforce        → ~/.claude/skills/
#     skills/securing-agentforce         → ~/.claude/skills/
#
# Idempotent: safe to re-run after a `git pull`.
# Requires: bash, curl or git, python3 (for the upstream installer).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_SRC="$ROOT/skills/agentforce-to-agent-script"
AGENTS_SRC="$ROOT/agents"
SKILL_DST="$HOME/.claude/skills/agentforce-to-agent-script"
AGENTS_DST="$HOME/.claude/agents"

UPSTREAM_INSTALL_URL="https://raw.githubusercontent.com/SalesforceAIResearch/agentforce-adlc/main/tools/install.sh"

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

echo -e "${BOLD}Agentforce ADLC — full-stack installer${NC}"
echo ""

# ── sanity checks ─────────────────────────────────────────────────────────────
[[ -f "$SKILL_SRC/SKILL.md" ]] \
  || die "$SKILL_SRC/SKILL.md not found. Run from the agentforce-converter-claude repo root."

[[ -d "$AGENTS_SRC" ]] \
  || die "$AGENTS_SRC not found."

[[ -d "$HOME/.claude" ]] \
  || die "~/.claude not found. Install Claude Code first: npm install -g @anthropic-ai/claude-code"

# ── 1. local skill: agentforce-to-agent-script ────────────────────────────────
step "Installing skill: agentforce-to-agent-script"
if [[ -d "$SKILL_DST" ]]; then
  rm -rf "$SKILL_DST"
fi
cp -R "$SKILL_SRC" "$SKILL_DST"
ok "~/.claude/skills/agentforce-to-agent-script"

# ── 2. local agents ───────────────────────────────────────────────────────────
step "Installing agents"
mkdir -p "$AGENTS_DST"
for agent_file in "$AGENTS_SRC"/*.md; do
  fname="$(basename "$agent_file")"
  cp "$agent_file" "$AGENTS_DST/$fname"
  ok "~/.claude/agents/$fname"
done

# ── 3. upstream skills (developing / testing / observing / securing) ──────────
step "Installing upstream ADLC skills from SalesforceAIResearch/agentforce-adlc"

if command -v python3 &>/dev/null; then
  python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "0.0")
  python_major=${python_version%%.*}
  python_minor=${python_version#*.}; python_minor=${python_minor%%.*}
  if [[ "$python_major" -ge 3 && "$python_minor" -ge 9 ]]; then
    if command -v curl &>/dev/null; then
      bash <(curl -fsSL "$UPSTREAM_INSTALL_URL") --target claude
      ok "upstream ADLC skills installed"
    else
      warn "curl not found — skipping upstream skill install. Run manually:"
      warn "  curl -sSL $UPSTREAM_INSTALL_URL | bash -s -- --target claude"
    fi
  else
    warn "Python $python_version found but 3.9+ required — skipping upstream install."
    warn "Install Python 3.9+ and re-run, or install upstream skills manually:"
    warn "  curl -sSL $UPSTREAM_INSTALL_URL | bash -s -- --target claude"
  fi
else
  warn "python3 not found — skipping upstream skill install."
  warn "Install Python 3.9+ and re-run, or install upstream skills manually:"
  warn "  curl -sSL $UPSTREAM_INSTALL_URL | bash -s -- --target claude"
fi

# ── 4. sfdx-project.json ─────────────────────────────────────────────────────
step "Checking sfdx-project.json"
if [[ -f "$ROOT/sfdx-project.json" ]]; then
  ok "sfdx-project.json present (required for sf project deploy/retrieve)"
else
  warn "sfdx-project.json not found at repo root. SF CLI deploy/retrieve will fail."
  warn "Expected: $ROOT/sfdx-project.json"
fi

# ── 5. verify ─────────────────────────────────────────────────────────────────
echo ""
step "Verifying installation"

check() {
  local path="$1" label="$2"
  if [[ -e "$path" ]]; then
    ok "$label"
  else
    warn "MISSING: $label ($path)"
  fi
}

check "$HOME/.claude/skills/agentforce-to-agent-script/SKILL.md"     "skill: agentforce-to-agent-script"
check "$HOME/.claude/agents/agentforce-converter.md"                   "agent: agentforce-converter"
check "$HOME/.claude/agents/adlc-orchestrator.md"                      "agent: adlc-orchestrator"
check "$HOME/.claude/agents/adlc-author.md"                            "agent: adlc-author"
check "$HOME/.claude/agents/adlc-engineer.md"                          "agent: adlc-engineer"
check "$HOME/.claude/agents/adlc-qa.md"                                "agent: adlc-qa"
check "$HOME/.claude/skills/developing-agentforce/SKILL.md"            "skill: developing-agentforce"
check "$HOME/.claude/skills/testing-agentforce/SKILL.md"               "skill: testing-agentforce"
check "$HOME/.claude/skills/observing-agentforce/SKILL.md"             "skill: observing-agentforce"
check "$HOME/.claude/skills/securing-agentforce/SKILL.md"              "skill: securing-agentforce"

echo ""
echo -e "${BOLD}Done.${NC}"
echo ""
echo "Full pipeline is ready. Example usage:"
echo ""
echo "  Authenticate your org:  ./scripts/org-auth.sh"
echo "  Convert a legacy JSON:  \"Use the agentforce-to-agent-script skill to convert /path/to/agent.json\""
echo "  Full ADLC pipeline:     \"Use adlc-orchestrator to convert, deploy, and test /path/to/agent.json\""
echo ""
echo "Re-run after a git pull to pick up spec/example updates."
echo "See HOWTO.md Section 3 for org authentication and metadata setup."
