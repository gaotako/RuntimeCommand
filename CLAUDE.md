# AI Agent Rules

## Synchronized Settings

Model and API settings exist in multiple locations. Update ALL together:
- `ai_agents/claude/settings.json` → `"model"` (template for coldstart)
- `code_server/User/settings.json` → `"claudeCode.selectedModel"` (VS Code extension)

## Host vs Container

- Host `$HOME` has `~/.toolbox/`, `~/.aim/`, `~/brazil-pkg-cache/`.
- Container home is `$DOCKER_HOME` (from `config.sh`), typically `$WORKSPACE/CodeServerDockerHome`.
- Paths in `docker exec` env vars must use `DOCKER_HOME`, not `$HOME`.
- Never run host-side validation scripts inside the container via `docker exec`.
