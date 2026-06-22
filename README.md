# agentforce-converter-claude

A self-contained Claude Code stack that covers the **full Agentforce Agent Development Life Cycle** — from legacy JSON conversion through authoring, deployment, testing, and security assessment.

## Prerequisites

| Requirement | Notes |
|---|---|
| [Claude Code](https://github.com/anthropics/claude-code) | `npm install -g @anthropic-ai/claude-code` |
| Python 3.9+ | Required by the upstream ADLC skill installer |
| curl | Required to pull upstream skills during install |
| [Salesforce CLI v2](https://developer.salesforce.com/tools/salesforcecli) | Required for deploy/test phases; optional for conversion-only use |
| Agentforce-enabled Salesforce org | Required for deploy/test phases |

## What's included

### Local (this repo)

| Component | What it does |
|---|---|
| `skills/agentforce-to-agent-script` | Converts legacy Agentforce JSON exports (plugin/topic/function model) to Agent Script `.agent` YAML |
| `agents/agentforce-converter.md` | Subagent wrapper — callable by the orchestrator for legacy conversions |
| `agents/adlc-orchestrator.md` | Plan-mode orchestrator for the full 7-phase ADLC (patched to include Phase 0 legacy conversion) |
| `agents/adlc-author.md` | Writes `.agent` files from requirements |
| `agents/adlc-engineer.md` | Scaffolds Flow/Apex metadata and deploys bundles |
| `agents/adlc-qa.md` | Tests agents and optimizes via session trace analysis |

### Upstream (pulled from [SalesforceAIResearch/agentforce-adlc](https://github.com/SalesforceAIResearch/agentforce-adlc) during install)

| Skill | What it does |
|---|---|
| `developing-agentforce` | Author, validate, deploy, publish agents |
| `testing-agentforce` | Smoke tests, batch test suites, CI integration |
| `observing-agentforce` | Production session trace analysis via Data Cloud |
| `securing-agentforce` | OWASP LLM Top 10 security assessment (57 tests, A–F grade) |

## Install

```bash
git clone https://github.com/crmoraes/agentforce-converter-claude ~/Dev/agentforce-converter-claude
cd ~/Dev/agentforce-converter-claude
./scripts/install.sh
```

Requires: Claude Code, Python 3.9+, curl. Salesforce CLI optional (needed for deploy/test phases).

The script is idempotent — re-run it after `git pull` to pick up spec or example updates.

## Full pipeline (legacy JSON → live agent)

```
Legacy JSON
    │
    ▼  Phase 0 — agentforce-converter
    │  Converts JSON to Agent Script YAML
    │
    ▼  Phase 1 — Requirements review
    │  Resolve placeholder targets and flagged uncertainties
    │
    ▼  Phase 2 — adlc-author (developing-agentforce)
    │  Refines/finalizes the .agent file
    │
    ▼  Phase 3+4 — adlc-engineer (developing-agentforce)
    │  Discovers missing flows/apex, scaffolds stubs, deploys
    │
    ▼  Phase 5 — Deploy, publish, activate
    │
    ▼  Phase 6 — adlc-qa (testing-agentforce)
    │  Smoke tests, trace analysis, optimization
    │
    ▼  Phase 7 — adlc-qa → securing-agentforce
       OWASP LLM Top 10 security assessment
```

Drive the whole pipeline with one prompt:

```
Use adlc-orchestrator to convert, deploy, and test /path/to/agent.json against my org.
```

Or use each piece independently:

```
# Convert only
Use the agentforce-to-agent-script skill to convert /path/to/agent.json

# Deploy only (if you already have a .agent file)
Use developing-agentforce to validate and publish My_Agent to my org.

# Test only
Use testing-agentforce to run smoke tests on My_Agent.

# Security scan only
Use securing-agentforce to run a full assessment on My_Agent.
```

## Getting your legacy Agentforce JSON

1. Navigate to your Salesforce org.
2. Append `/support/qa/planner.jsp` to the base URL.
3. Select your agent and copy/download the JSON.

See [WALKTHROUGH.md](./WALKTHROUGH.md) for a step-by-step tutorial using the included sample agent (Path A: conversion only; Path B: full ADLC pipeline).

See [HOWTO.md](./HOWTO.md) for the full reference guide, known limitations, and troubleshooting.

## Architecture

No compiled converter, no rules engine. The conversion skill works by:

1. Loading a living spec (`agent-script-spec.md`) — the single source of truth for Agent Script format.
2. Matching against five worked examples (input JSON ↔ output `.agent` pairs).
3. Following a short procedural playbook.

When Agent Script evolves, update the spec and (optionally) add a new example — no code to change.

## Updating

```bash
git pull
./scripts/install.sh   # re-installs local files + pulls latest upstream skills
```
