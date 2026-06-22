#!/usr/bin/env python3
"""
assemble_legacy_agent.py

Parse retrieved GenAiPlugin and GenAiFunction XML metadata and assemble them
into the Shape A planner JSON that the agentforce-to-agent-script conversion
skill expects.

Called by retrieve-legacy-agent.sh — not intended to be invoked directly
(though it works standalone with --help).

Produces a JSON file whose top-level structure matches the planner export from
  https://<org>.salesforce.com/support/qa/planner.jsp
so the conversion skill can process it without any special-casing.

Fields that cannot be derived from retrieved metadata are emitted with a
"TODO_REPLACE" sentinel string so the conversion skill flags them clearly
in its Notes output rather than silently using wrong defaults.
"""

import argparse
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


# Salesforce metadata XML namespace
NS = "http://soap.sforce.com/2006/04/metadata"

# Fields the conversion skill reads from the planner JSON top level
AGENT_FIELDS = {
    "name", "label", "description", "plannerRole", "plannerCompany",
    "plannerToneType", "locale", "secondaryLocales", "welcomeMessage",
    "id", "plugins", "variables",
}


def ns(tag: str) -> str:
    return f"{{{NS}}}{tag}"


def text(el, tag: str, default: str = "") -> str:
    child = el.find(ns(tag))
    return (child.text or default).strip() if child is not None else default


def bool_text(el, tag: str, default: bool = False) -> bool:
    val = text(el, tag, str(default)).lower()
    return val in ("true", "1", "yes")


# ── XML parsers ───────────────────────────────────────────────────────────────

def parse_gen_ai_function(path: Path) -> dict:
    """
    Parse a GenAiFunction-meta.xml file into the function dict shape
    used inside a plugin's `functions[]` array.
    """
    tree = ET.parse(path)
    root = tree.getroot()

    # Strip namespace from tag for comparison
    def local(tag):
        return tag.split("}")[-1] if "}" in tag else tag

    func = {
        "name": path.stem.replace("-meta", ""),
        "label": text(root, "masterLabel") or path.stem.replace("-meta", ""),
        "description": text(root, "description"),
        "requireUserConfirmation": bool_text(root, "requireUserConfirmation", False),
        "requireUserVerification": bool_text(root, "requireUserVerification", False),
        "includeInProgressIndicator": bool_text(root, "includeInProgressIndicator", False),
        "inputs": [],
        "outputs": [],
    }

    # invocationTarget + invocationTargetType
    invoc_target = text(root, "invocationTargetName") or text(root, "invocationTarget")
    invoc_type = text(root, "invocationTargetType", "flow")
    func["invocationTarget"] = invoc_target or f"TODO_REPLACE_{func['name']}"
    func["invocationTargetType"] = invoc_type

    # inputs
    for param in root.findall(f".//{ns('inputParams')}") + root.findall(f".//{ns('inputParameters')}"):
        p = {
            "name": text(param, "name") or text(param, "developerName"),
            "dataType": _map_type(text(param, "dataType", "string")),
            "description": text(param, "description"),
            "isRequired": bool_text(param, "isRequired", False),
            "isUserInput": bool_text(param, "isUserInput", False),
        }
        if p["name"]:
            func["inputs"].append(p)

    # outputs
    for param in root.findall(f".//{ns('outputParams')}") + root.findall(f".//{ns('outputParameters')}"):
        p = {
            "name": text(param, "name") or text(param, "developerName"),
            "dataType": _map_type(text(param, "dataType", "string")),
            "description": text(param, "description"),
            "isDisplayable": bool_text(param, "isDisplayable", False),
            "isUsedByPlanner": bool_text(param, "isUsedByPlanner", True),
        }
        if p["name"]:
            func["outputs"].append(p)

    return func


def parse_gen_ai_plugin(path: Path, functions_by_name: dict) -> dict:
    """
    Parse a GenAiPlugin-meta.xml file into the plugin dict shape used in
    the planner JSON's `plugins[]` array.
    """
    tree = ET.parse(path)
    root = tree.getroot()

    plugin_name = path.stem.replace("-meta", "")
    plugin = {
        "id": "",
        "name": plugin_name,
        "localDevName": text(root, "developerName") or plugin_name,
        "label": text(root, "masterLabel") or plugin_name,
        "description": text(root, "description"),
        "scope": text(root, "scope") or text(root, "additionalInstructions"),
        "pluginType": text(root, "pluginType", "TOPIC"),
        "instructionDefinitions": [],
        "functions": [],
        "canEscalate": bool_text(root, "canEscalate", False),
    }

    # instructionDefinitions — from <instructions> children or <additionalInstructions>
    for instr in root.findall(f".//{ns('instructions')}"):
        desc = text(instr, "description") or text(instr, "label") or instr.text or ""
        if desc.strip():
            plugin["instructionDefinitions"].append({
                "name": text(instr, "name") or text(instr, "developerName") or "",
                "label": text(instr, "label") or "",
                "description": desc.strip(),
            })

    # functions — look up each <genAiFunctions> reference in the pre-parsed map
    for fn_ref in root.findall(f".//{ns('genAiFunctions')}") + root.findall(f".//{ns('functions')}"):
        fn_name = text(fn_ref, "name") or text(fn_ref, "developerName") or fn_ref.text or ""
        fn_name = fn_name.strip()
        if fn_name and fn_name in functions_by_name:
            plugin["functions"].append(functions_by_name[fn_name])
        elif fn_name:
            # Function referenced in plugin but XML not found — emit a stub
            plugin["functions"].append({
                "name": fn_name,
                "label": fn_name,
                "description": f"TODO_REPLACE — function XML not found for {fn_name}",
                "invocationTarget": f"TODO_REPLACE_{fn_name}",
                "invocationTargetType": "flow",
                "inputs": [],
                "outputs": [],
            })

    return plugin


def parse_bot_metadata(path: Path) -> dict:
    """
    Parse Bot-meta.xml for agent-level fields: label, description,
    welcomeMessage, locale, plannerRole, plannerCompany.
    Returns a partial dict — only the fields that are present.
    """
    if not path.exists():
        return {}

    tree = ET.parse(path)
    root = tree.getroot()

    result = {}
    label = text(root, "botMasterLabel") or text(root, "masterLabel")
    if label:
        result["label"] = label
    desc = text(root, "description")
    if desc:
        result["description"] = desc
    locale = text(root, "defaultLocale") or text(root, "locale")
    if locale:
        result["locale"] = locale
    welcome = text(root, "welcomeMessage")
    if welcome:
        result["welcomeMessage"] = welcome

    # BotVersion may carry plannerRole / plannerCompany in <conversationSystemMessage>
    sys_msg = text(root, "conversationSystemMessage")
    if sys_msg:
        result["_systemMessage"] = sys_msg  # assembler will split into role/company

    return result


# ── type mapper ───────────────────────────────────────────────────────────────

def _map_type(sf_type: str) -> str:
    """Map Salesforce metadata type names to the simple type strings used in
    the planner JSON (which the conversion skill then maps to Agent Script types)."""
    mapping = {
        "string": "string",
        "text": "string",
        "boolean": "boolean",
        "integer": "integer",
        "int": "integer",
        "double": "number",
        "decimal": "number",
        "date": "date",
        "datetime": "datetime",
        "currency": "currency",
        "id": "string",
        "reference": "string",
        "picklist": "string",
        "multipicklist": "string",
        "textarea": "string",
        "longtextarea": "string",
        "richtextarea": "string",
        "url": "string",
        "email": "string",
        "phone": "string",
        "percent": "number",
        "object": "object",
    }
    return mapping.get(sf_type.lower(), "string")


# ── agent-name filter ─────────────────────────────────────────────────────────

def plugin_belongs_to_agent(plugin_name: str, agent_name: str) -> bool:
    """
    Legacy Agentforce plugin API names follow the pattern:
      <TopicLocalDevName>_<BotId>   e.g. Order_Status_16jKc0000004Cqw
    or simply match the agent name as a prefix.
    This heuristic matches plugins that end with a Salesforce ID-shaped suffix
    OR are explicitly listed in the tooling API results filtered by agent name.
    If unsure, the script includes all plugins and lets the user filter.
    """
    # If the plugin name matches the agent name exactly, include it
    if plugin_name.startswith(agent_name):
        return True

    # Salesforce ID pattern: 15 or 18 alphanumeric chars
    sf_id_pattern = re.compile(r"_[A-Za-z0-9]{15,18}$")
    if sf_id_pattern.search(plugin_name):
        return True  # looks like it belongs to some agent — include; user can prune

    return False


# ── main assembler ────────────────────────────────────────────────────────────

def assemble(
    source_dir: Path,
    agent_name: str,
    tooling_plugins: dict,
    tooling_functions: dict,
) -> dict:
    """
    Walk the retrieved XML files, parse them, and assemble a Shape A planner JSON.
    """
    plugins_dir = source_dir / "genAiPlugins"
    functions_dir = source_dir / "genAiFunctions"
    bots_dir = source_dir / "bots"

    # ── 1. parse all GenAiFunction XML files ──────────────────────────────────
    functions_by_name: dict[str, dict] = {}

    if functions_dir.exists():
        for xml_file in sorted(functions_dir.glob("*.xml")):
            try:
                fn = parse_gen_ai_function(xml_file)
                functions_by_name[fn["name"]] = fn
            except ET.ParseError as exc:
                print(f"  ⚠ Skipping malformed XML: {xml_file.name} ({exc})", file=sys.stderr)
    else:
        print(f"  ⚠ {functions_dir} not found — no GenAiFunction metadata retrieved.",
              file=sys.stderr)

    # ── 2. parse all GenAiPlugin XML files ────────────────────────────────────
    all_plugins: list[dict] = []

    if plugins_dir.exists():
        for xml_file in sorted(plugins_dir.glob("*.xml")):
            try:
                plugin = parse_gen_ai_plugin(xml_file, functions_by_name)
                if plugin["pluginType"] == "TOPIC":
                    all_plugins.append(plugin)
            except ET.ParseError as exc:
                print(f"  ⚠ Skipping malformed XML: {xml_file.name} ({exc})", file=sys.stderr)
    else:
        print(f"  ⚠ {plugins_dir} not found — no GenAiPlugin metadata retrieved.",
              file=sys.stderr)

    # ── 3. filter plugins to those belonging to this agent ───────────────────
    agent_plugins = [p for p in all_plugins if plugin_belongs_to_agent(p["name"], agent_name)]

    if not agent_plugins and all_plugins:
        # Can't determine ownership — include all TOPIC plugins and warn
        print(
            f"  ⚠ Could not match plugins to agent '{agent_name}' by name pattern.\n"
            f"    Including all {len(all_plugins)} TOPIC plugin(s) found. "
            f"Prune manually if needed.",
            file=sys.stderr,
        )
        agent_plugins = all_plugins

    # Normalise localDevName from the suffix pattern: "Order_Status_16jKc..." → "Order_Status"
    sf_id_pattern = re.compile(r"_[A-Za-z0-9]{15,18}$")
    for p in agent_plugins:
        p["localDevName"] = sf_id_pattern.sub("", p["name"])

    # ── 4. Bot-level fields ───────────────────────────────────────────────────
    bot_meta: dict = {}
    if bots_dir.exists():
        for candidate in [
            bots_dir / f"{agent_name}_Bot" / f"{agent_name}_Bot.bot-meta.xml",
            bots_dir / f"{agent_name}" / f"{agent_name}.bot-meta.xml",
        ]:
            if candidate.exists():
                bot_meta = parse_bot_metadata(candidate)
                break

    # ── 5. assemble the top-level planner JSON ────────────────────────────────
    agent_label = bot_meta.get("label", agent_name.replace("_", " "))
    agent_description = bot_meta.get(
        "description",
        f"TODO_REPLACE — add a description for {agent_label}",
    )
    locale = bot_meta.get("locale", "en_US")
    welcome = bot_meta.get(
        "welcomeMessage",
        f"Hi, I'm {agent_label}. How can I help you today?",
    )

    # plannerRole / plannerCompany: derive from _systemMessage if available,
    # otherwise emit TODO sentinels — the conversion skill will flag these
    system_msg = bot_meta.get("_systemMessage", "")
    if system_msg:
        planner_role = system_msg
        planner_company = "TODO_REPLACE — extract company context from plannerRole if needed"
    else:
        planner_role = (
            f"TODO_REPLACE — describe the agent's role and persona for {agent_label}"
        )
        planner_company = (
            "TODO_REPLACE — describe your company's products or services"
        )

    result = {
        "name": agent_name,
        "label": agent_label,
        "description": agent_description,
        "plannerRole": planner_role,
        "plannerCompany": planner_company,
        "plannerToneType": "CASUAL",
        "locale": locale,
        "secondaryLocales": [],
        "welcomeMessage": welcome,
        "id": f"retrieved_{agent_name}",
        "plugins": agent_plugins,
        "variables": [],
    }

    return result


# ── CLI ────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Assemble a Shape A planner JSON from retrieved Salesforce XML metadata."
    )
    parser.add_argument(
        "--source-dir",
        required=True,
        type=Path,
        help="Path to force-app/main/default (or whichever dir holds genAiPlugins/ and genAiFunctions/)",
    )
    parser.add_argument(
        "--agent-name",
        required=True,
        help="API name (DeveloperName) of the legacy Agentforce agent.",
    )
    parser.add_argument(
        "--output",
        required=True,
        type=Path,
        help="Destination path for the assembled JSON file.",
    )
    parser.add_argument(
        "--tooling-plugins",
        default="{}",
        help="JSON string from sf data query on GenAiPlugin (for supplementary metadata).",
    )
    parser.add_argument(
        "--tooling-functions",
        default="{}",
        help="JSON string from sf data query on GenAiFunction (for supplementary metadata).",
    )
    args = parser.parse_args()

    try:
        tooling_plugins = json.loads(args.tooling_plugins)
    except json.JSONDecodeError:
        tooling_plugins = {}
    try:
        tooling_functions = json.loads(args.tooling_functions)
    except json.JSONDecodeError:
        tooling_functions = {}

    if not args.source_dir.exists():
        print(f"Error: source-dir not found: {args.source_dir}", file=sys.stderr)
        sys.exit(1)

    result = assemble(
        source_dir=args.source_dir,
        agent_name=args.agent_name,
        tooling_plugins=tooling_plugins,
        tooling_functions=tooling_functions,
    )

    # Count how many TODO sentinels are present
    result_str = json.dumps(result, indent=2, ensure_ascii=False)
    todo_count = result_str.count("TODO_REPLACE")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(result_str, encoding="utf-8")

    # Summary
    plugin_count = len(result["plugins"])
    func_count = sum(len(p.get("functions", [])) for p in result["plugins"])
    print(f"  ✓ Assembled {plugin_count} topic(s), {func_count} function(s)")
    if todo_count:
        print(
            f"  ⚠ {todo_count} TODO_REPLACE sentinel(s) in output — review before converting.\n"
            f"    Search for 'TODO_REPLACE' in {args.output}"
        )
    else:
        print("  ✓ No TODO sentinels — all fields resolved from retrieved metadata.")


if __name__ == "__main__":
    main()
