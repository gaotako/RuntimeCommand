# TODO: Multi-Platform Support

## Cross-Platform Docker Deployment

The setup now supports SageMaker and Linux (AL2 Cloud Desktop) platforms.
The following tasks remain for full cross-platform coverage.

---

### ~~1. Platform Detection~~ ✅

Platform detection is implemented in `config.sh` via `RC_PLATFORM`:
- `sagemaker`: SageMaker Notebook Instance (ec2-user, `~/SageMaker` present).
- `linux`: Generic Linux / AL2 Cloud Desktop (default for Linux).
- `macos`: macOS (Darwin kernel) — detected but not yet fully supported.

Override manually: `RC_PLATFORM=linux bash install.sh`.

### ~~2. Wrapper / Entry Point Differences~~ ✅

- SageMaker: `sagemaker/wrapper.sh` launches Docker via `jupyter-server-proxy`.
- Linux: `linux/wrapper.sh` launches Docker directly with `--port` / `--detach`.
- The Docker container itself (Dockerfile, `rc.sh`, `mise.sh`) is
  platform-agnostic. Only the host-side orchestration differs.

### ~~3. AI Agent Configuration~~ ✅

- `claude/settings.json`: Same across platforms (Bedrock via AWS profile).
- `cline/globalState-template.json`: Uses `${WORKSPACE}` placeholder resolved
  at setup time via `sed` — produces platform-correct paths automatically.
- `rc.sh` host guard now shows platform-appropriate hints.

---

### 4. Share Code-Server Settings with Host VS Code

- [ ] Symlink or mount `code_server/User/settings.json` to the host VS Code
      settings directory:
  - macOS: `~/Library/Application Support/Code/User/settings.json`
  - Linux (AL2): `~/.config/Code/User/settings.json`
- [ ] Handle merge strategy: code-server settings are a superset of VS Code
      settings (some keys like `code-eol.*` are code-server-only). Consider a
      shared base + platform-specific overrides.
- [ ] Machine settings (`settings-template.json`) may need different Python
      paths on each platform (mise-managed vs system).

### 5. Extension List Divergence

- [ ] Create platform-specific extension lists or use conditional logic:
  - **SageMaker (code-server):** Uses `saoudrizwan.claude-dev` (Cline open-source)
    and `Anthropic.claude-code` (Claude Code).
  - **AL2 Cloud Desktop / macOS (VS Code):** May use Cline (Amazon Internal)
    instead of native Cline. Extension ID differs.
- [ ] Consider a `profiles/` directory structure:
  ```
  code_server/Data/SyncSettings/profiles/
  ├── sagemaker/extensions.yml     # code-server extensions
  ├── linux/extensions.yml         # AL2 extensions (Cline internal)
  └── macos/extensions.yml         # macOS extensions (Cline internal)
  ```
- [ ] Update `coldstart.sh` or equivalent to select the correct profile based
      on the detected platform.

### 6. SSH / AWS Credential Sharing

- [ ] Current setup symlinks `~/.ssh` and `~/.aws` from Docker home to
      persistent storage. On Cloud Desktop / macOS, the host already has
      these directories — sharing strategy may differ (mount host dirs
      directly vs symlink).

### 7. macOS Support

- [ ] Create `macos/` directory (parallel to `linux/` and `sagemaker/`).
- [ ] Handle macOS-specific paths (`~/Library/Application Support/Code/...`).
- [ ] Test Docker Desktop for Mac compatibility.