# TODO: Multi-Platform Support

## Cross-Platform Docker Deployment

The current setup is SageMaker-specific. The following tasks are needed to
support AL2 Cloud Desktop and macOS environments.

---

### 1. Share Code-Server Settings with Host VS Code

- [ ] Symlink or mount `code_server/User/settings.json` to the host VS Code
      settings directory:
  - macOS: `~/Library/Application Support/Code/User/settings.json`
  - Linux (AL2): `~/.config/Code/User/settings.json`
- [ ] Handle merge strategy: code-server settings are a superset of VS Code
      settings (some keys like `code-eol.*` are code-server-only). Consider a
      shared base + platform-specific overrides.
- [ ] Machine settings (`settings-template.json`) may need different Python
      paths on each platform (mise-managed vs system).

### 2. Extension List Divergence

- [ ] Create platform-specific extension lists or use conditional logic:
  - **SageMaker (code-server):** Uses `saoudrizwan.claude-dev` (Cline open-source)
    and `Anthropic.claude-code` (Claude Code).
  - **AL2 Cloud Desktop / macOS (VS Code):** May use Cline (Amazon Internal)
    instead of native Cline. Extension ID differs.
- [ ] Consider a `profiles/` directory structure:
  ```
  code_server/Data/SyncSettings/profiles/
  ├── sagemaker/extensions.yml     # code-server extensions
  ├── cloud-desktop/extensions.yml # AL2 extensions (Cline internal)
  └── macos/extensions.yml         # macOS extensions (Cline internal)
  ```
- [ ] Update `coldstart.sh` or equivalent to select the correct profile based
      on the detected platform.

### 3. Platform Detection

- [ ] Add a platform detection mechanism (e.g., `PLATFORM` env var or
      auto-detect from `uname -s` / hostname pattern):
  - `sagemaker`: SageMaker Notebook Instance (ec2-user, Jupyter present)
  - `cloud-desktop`: AL2 Cloud Desktop (gajianfe, no Jupyter)
  - `macos`: macOS (darwin kernel)
- [ ] Gate SageMaker-specific scripts (`setup_jupyter.sh`, `coldstart.sh`)
      behind platform checks.

### 4. Wrapper / Entry Point Differences

- [ ] SageMaker: `wrapper.sh` launches Docker via `jupyter-server-proxy`.
- [ ] Cloud Desktop / macOS: Docker is started manually or via a simpler
      launcher script. No Jupyter proxy needed.
- [ ] The Docker container itself (Dockerfile, `rc.sh`, `mise.sh`) is
      platform-agnostic. Only the host-side orchestration differs.

### 5. AI Agent Configuration

- [ ] `claude/settings.json`: Same across platforms (Bedrock via AWS profile).
- [ ] `cline/globalState.json`: Workspace path differs per platform.
  - SageMaker: `/home/ec2-user/SageMaker/CodeServerDockerHome/Workspace`
  - Cloud Desktop: `${HOME}/Workspace` (or Docker-mounted equivalent)
  - macOS: `${HOME}/Workspace`
- [ ] Cline extension ID:
  - SageMaker (code-server): `saoudrizwan.claude-dev`
  - Cloud Desktop / macOS (VS Code): Amazon Internal Cline (different ID)

### 6. SSH / AWS Credential Sharing

- [ ] Current setup symlinks `~/.ssh` and `~/.aws` from Docker home to
      persistent storage. On Cloud Desktop / macOS, the host already has
      these directories — sharing strategy may differ (mount host dirs
      directly vs symlink).