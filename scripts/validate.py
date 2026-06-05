#!/usr/bin/env python3
"""
Structural validator for the roundhouse plugin.

Catches the same things `claude plugin validate` does — without requiring
Claude Code to be installed. Runs in CI on a stock Ubuntu image.

Checks:
- .claude-plugin/plugin.json: valid JSON, required fields, sensible types
- hooks/hooks.json: valid JSON with the nested matcher → hooks: [{type, command}] shape
- agents/*.md: YAML frontmatter parses, required fields present, model is valid
- skills/*/SKILL.md: YAML frontmatter parses, required fields present
"""

from __future__ import annotations
import json
import sys
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
errors: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def parse_yaml_frontmatter(path: Path) -> dict | None:
    """Minimal YAML frontmatter parser — handles the keys we use."""
    text = path.read_text()
    if not text.startswith("---\n"):
        err(f"{path}: missing YAML frontmatter")
        return None
    end = text.find("\n---\n", 4)
    if end == -1:
        err(f"{path}: unterminated YAML frontmatter")
        return None
    body = text[4:end]
    out: dict[str, str] = {}
    for line in body.splitlines():
        m = re.match(r"^([a-z_]+):\s*(.*)$", line)
        if not m:
            continue
        key, raw = m.group(1), m.group(2).strip()
        # Strip surrounding quotes on the value
        if (raw.startswith('"') and raw.endswith('"')) or (raw.startswith("'") and raw.endswith("'")):
            raw = raw[1:-1]
        out[key] = raw
    return out


def check_plugin_manifest() -> None:
    path = ROOT / ".claude-plugin" / "plugin.json"
    if not path.exists():
        err(".claude-plugin/plugin.json: missing")
        return
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        err(f"{path}: invalid JSON: {e}")
        return
    for key in ("name", "version", "description"):
        if key not in data:
            err(f"plugin.json: missing required field '{key}'")
    if "skills" in data and not isinstance(data["skills"], str):
        err("plugin.json: 'skills' must be a string path")
    if "hooks" in data and not isinstance(data["hooks"], str):
        err("plugin.json: 'hooks' must be a string path")
    if "agents" in data:
        err("plugin.json: 'agents' is not a supported field — agents auto-discover from agents/")


def check_hooks_json() -> None:
    path = ROOT / "hooks" / "hooks.json"
    if not path.exists():
        return  # hooks are optional
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        err(f"{path}: invalid JSON: {e}")
        return
    hooks = data.get("hooks", {})
    if not isinstance(hooks, dict):
        err(f"{path}: 'hooks' must be an object")
        return
    for event_name, entries in hooks.items():
        if not isinstance(entries, list):
            err(f"{path}: hooks.{event_name} must be an array")
            continue
        for i, entry in enumerate(entries):
            if "matcher" not in entry:
                err(f"{path}: hooks.{event_name}[{i}] missing 'matcher'")
            inner = entry.get("hooks")
            if not isinstance(inner, list):
                err(f"{path}: hooks.{event_name}[{i}].hooks must be an array of {{type, command}} objects")
                continue
            for j, h in enumerate(inner):
                if h.get("type") != "command":
                    err(f"{path}: hooks.{event_name}[{i}].hooks[{j}].type must be 'command'")
                if not h.get("command"):
                    err(f"{path}: hooks.{event_name}[{i}].hooks[{j}] missing 'command'")
            if "filePatterns" in entry:
                err(f"{path}: hooks.{event_name}[{i}] has unsupported 'filePatterns' field — filter inside the hook script instead")


def check_agents() -> None:
    agents_dir = ROOT / "agents"
    if not agents_dir.is_dir():
        return
    valid_models = {"claude-opus-4-7", "claude-sonnet-4-6", "claude-haiku-4-5-20251001", "sonnet", "opus", "haiku"}
    for path in sorted(agents_dir.glob("*.md")):
        fm = parse_yaml_frontmatter(path)
        if fm is None:
            continue
        for key in ("name", "description"):
            if key not in fm:
                err(f"{path}: frontmatter missing '{key}'")
        if "model" in fm and fm["model"] not in valid_models:
            err(f"{path}: unknown model '{fm['model']}' — expected one of {sorted(valid_models)}")
        # Sanity-check description is quoted if it contains a colon (the silent-drop trap)
        body = path.read_text().split("\n---\n")[0]
        desc_line = next((l for l in body.splitlines() if l.startswith("description:")), None)
        if desc_line and ":" in desc_line[len("description:"):].strip():
            stripped = desc_line[len("description:"):].strip()
            if not (stripped.startswith('"') or stripped.startswith("'")):
                err(f"{path}: description contains a ':' but isn't quoted — YAML may drop the entire frontmatter silently")


def check_skills() -> None:
    skills_dir = ROOT / "skills"
    if not skills_dir.is_dir():
        return
    for skill_dir in sorted(skills_dir.iterdir()):
        if not skill_dir.is_dir():
            continue
        skill_md = skill_dir / "SKILL.md"
        if not skill_md.exists():
            err(f"{skill_dir}: missing SKILL.md")
            continue
        fm = parse_yaml_frontmatter(skill_md)
        if fm is None:
            continue
        for key in ("name", "description"):
            if key not in fm:
                err(f"{skill_md}: frontmatter missing '{key}'")
        if fm.get("name") and fm["name"] != skill_dir.name:
            err(f"{skill_md}: name '{fm['name']}' does not match directory '{skill_dir.name}'")


def check_hook_scripts_executable() -> None:
    hooks_dir = ROOT / "hooks"
    if not hooks_dir.is_dir():
        return
    for path in hooks_dir.glob("*.sh"):
        if not path.stat().st_mode & 0o111:
            err(f"{path}: shell script is not executable (chmod +x)")


def check_hook_scripts_read_payload() -> None:
    """Guard against the CLAUDE_FILE regression.

    Claude Code delivers the PostToolUse payload as JSON on stdin — there is no
    CLAUDE_FILE env var. A hook that derives the edited path from $CLAUDE_FILE
    silently no-ops. Any hook that needs the edited file must instead read stdin
    (cat) and parse .tool_input.file_path.
    """
    hooks_dir = ROOT / "hooks"
    if not hooks_dir.is_dir():
        return
    var_re = re.compile(r"\$\{?CLAUDE_FILE\b")
    for path in sorted(hooks_dir.glob("*.sh")):
        text = path.read_text()
        # Only count code, not comments — the fix documents the trap in a comment.
        code = "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("#"))
        if var_re.search(code):
            err(f"{path}: expands $CLAUDE_FILE — Claude Code never sets it; "
                f"read the payload from stdin and parse .tool_input.file_path")
        # If a hook resolves the edited file path, it must read stdin to get it.
        if "file_path" in code and "cat" not in code:
            err(f"{path}: extracts file_path but never reads stdin (cat) — "
                f"the PostToolUse payload arrives on stdin")


def main() -> int:
    check_plugin_manifest()
    check_hooks_json()
    check_agents()
    check_skills()
    check_hook_scripts_executable()
    check_hook_scripts_read_payload()
    if errors:
        print(f"✘ {len(errors)} validation error(s):", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1
    print("✔ Plugin structure validation passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
