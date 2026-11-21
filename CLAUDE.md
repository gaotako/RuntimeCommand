# AI Agent Rules

## Scope

- This repo is a general-purpose runtime environment, not limited to Amazon-internal use.
- Amazon-internal behavior lives in a separate overlay package built on top of this one, which overrides or adds to it.
- Never put Amazon-only defaults, tooling, or policy here (e.g. toolbox installs, ASBX credentials); defaults must work for any user.

## Synchronized Settings

Model and API settings exist in multiple locations. Update ALL together:
- `ai_agents/claude/settings.json` → `"model"` (template for coldstart)
- `code_server/User/settings.json` → `"claudeCode.selectedModel"` (VS Code extension)

## Host vs Container

- Host `$HOME` has `~/.toolbox/`, `~/.aim/`, `~/brazil-pkg-cache/`.
- Container home is `$DOCKER_HOME` (from `config.sh`), typically `$WORKSPACE/CodeServerDockerHome`.
- Paths in `docker exec` env vars must use `DOCKER_HOME`, not `$HOME`.
- Never run host-side validation scripts inside the container via `docker exec`.
