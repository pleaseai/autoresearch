# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Claude Code plugin** called `autoresearch` — an autonomous experiment loop that modifies code, benchmarks, keeps improvements, and discards regressions. It follows the Claude Code plugin specification with commands, agents, skills, and hooks.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full system design and data flow.

## Plugin Structure

```
.claude-plugin/plugin.json    # Plugin manifest (name: "autoresearch")
commands/                     # Slash commands: run.md, status.md, cancel.md
agents/                       # Subagent: experiment-runner.md
skills/autoresearch/          # Background knowledge: SKILL.md + references/
hooks/                        # hooks.json + scripts/ (stop, session-start, compact)
scripts/                      # Utility: parse-metrics.sh
```

## Development

### Test locally

```bash
claude --plugin-dir /Volumes/Dev/IdeaProjects/claude-autoresearch
```

### Validate plugin structure

```bash
claude plugin validate .
```

### Debug hooks

```bash
claude --debug  # Shows hook registration, execution, and input/output
```

### Test hook scripts manually

```bash
# Stop hook
echo '{"stop_hook_active": false}' | CLAUDE_PROJECT_DIR=/tmp bash hooks/scripts/stop-hook.sh

# Session start hook
CLAUDE_PROJECT_DIR=/tmp bash hooks/scripts/session-start-hook.sh
```

Hook scripts require `jq` for JSON parsing.

## Key Architecture Decisions

- **Agent re-spawn pattern**: Commands never run experiments directly. They spawn the `experiment-runner` agent, which runs a batch in fresh context. The Stop hook re-spawns it automatically. This prevents context window overflow.
- **File-based state**: All state persists through `autoresearch.md` (session doc) and `autoresearch.jsonl` (experiment log). No in-memory state survives agent re-spawns.
- **Stop hook safety**: The stop hook MUST check `stop_hook_active` from stdin JSON to prevent infinite loops. Without this check, the hook blocks its own continuation indefinitely.

## Component Conventions

### Commands (`commands/*.md`)
- YAML frontmatter: `name`, `description`, `disable-model-invocation`, `allowed-tools`, `argument-hint`
- Commands that trigger side effects use `disable-model-invocation: true`

### Agents (`agents/*.md`)
- YAML frontmatter: `name`, `description`, `tools`, `model`, `maxTurns`, `skills`, `memory`, `color`
- Description must include `<example>` blocks for triggering
- Agent reads state from files on startup — never assumes prior context

### Skills (`skills/*/SKILL.md`)
- YAML frontmatter: `name`, `description`, `user-invocable`
- Background knowledge uses `user-invocable: false`
- Reference files via `${CLAUDE_SKILL_DIR}`

### Hooks (`hooks/hooks.json`)
- Wrapper format: `{"hooks": {"EventName": [...]}}`
- Scripts use `${CLAUDE_PLUGIN_ROOT}` for portable paths
- Scripts use `$CLAUDE_PROJECT_DIR` for user project files
- All hook scripts must be executable (`chmod +x`)

## Path Variables

| Variable | Context | Points to |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}` | Hook commands, MCP configs | This plugin's install directory |
| `$CLAUDE_PROJECT_DIR` | Hook scripts at runtime | User's project root |
| `${CLAUDE_SKILL_DIR}` | Skill content | The skill's subdirectory |
