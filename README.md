# Docker Code-Server for SageMaker

Run the latest code-server inside a Docker container on SageMaker Notebook Instances,
overcoming the AL2 glibc 2.26 limitation (code-server >= 4.17.0 requires glibc >= 2.28).

---

## File Structure

```
docker/
├── .gitignore                       Git ignore rules for build artifacts
├── Dockerfile                       Ubuntu 22.04 + code-server + zsh + AWS CLI + vim + tmux image
├── entrypoint.sh                    Dual-mode entrypoint (interactive shell / code-server)
├── build.sh                         Build the Docker image
├── config.sh                        Shared configuration and defaults
├── rc.sh                            Shell-agnostic runtime command initialization
├── home_setup.sh                    Persistent home directory overrides (.ssh, .aws, rc files)
├── mise.sh                          Mise runtime manager installation and setup
├── ai_agents/                       AI agent CLI installation and configuration
│   ├── claude.sh                    Claude Code CLI installation and setup
│   ├── claude/
│   │   └── settings.json            Claude Code CLI settings (model, auth, env)
│   ├── cline.sh                     Cline CLI installation and setup
│   ├── cline/
│   │   └── globalState.json         Cline global state (Bedrock API config)
│   └── kiro.sh                      Kiro CLI installation and setup
├── vimrc                            Vim configuration (sourced by ~/.vimrc)
├── shutils/                         Shared shell utility libraries
│   ├── argparse.sh                  Dynamic argument parser (--key value → VAR)
│   ├── log.sh                       BuildKit-style log indent builder
│   └── shell.sh                     Shell handler detection (CISH), project root (RC_DIR)
├── pyutils/                         Shared Python utility scripts
│   └── json_merge.py                Merge two JSON files (source keys on top of target)
├── code_server/                     Shared code-server settings (platform-independent)
│   ├── User/
│   │   └── settings.json            User-level settings (themes, formatters, etc.)
│   └── Data/
│       └── SyncSettings/
│           └── profiles/main/data/
│               └── extensions.yml   Extension list managed by sync-settings
├── sagemaker/                       SageMaker-specific scripts and data
│   ├── install.sh                   Install code-server (build + wrapper + verify)
│   ├── setup_jupyter.sh             Register code-server into JupyterLab launcher
│   ├── wrapper.sh                   Drop-in replacement for the code-server binary
│   ├── lifecycle/                   SageMaker lifecycle configuration hooks
│   │   └── notebook_instance/
│   │       ├── create.sh            First-time setup (build + install + register + coldstart)
│   │       └── start.sh             Every-start setup (load image + install + register)
│   ├── code_server/                 SageMaker-specific code-server settings
│   │   ├── coldstart.sh             Bootstrap settings symlinks and sync-settings extension
│   │   ├── Machine/
│   │   │   └── settings-template.json  Machine-level settings template (Python path resolved at coldstart)
│   │   └── User/
│   │       └── globalStorage/
│   │           └── zokugun.sync-settings/
│   │               └── settings-template.yml  Sync-settings config template
│   └── sagemaker_jproxy_launcher_ext/   JupyterLab extension for server-proxy launcher
│       ├── package.json             NPM metadata and build scripts
│       ├── pyproject.toml           Python build system config
│       ├── setup.py                 Python package installer
│       ├── setup.cfg                Package metadata
│       ├── install.json             Package manager metadata
│       ├── MANIFEST.in              Distribution file list
│       ├── tsconfig.json            TypeScript compiler config
│       ├── LICENSE                  BSD-3-Clause license
│       ├── .yarnrc.yml             Yarn config (disables PnP for jlpm compat)
│       ├── src/
│       │   ├── index.ts             Extension source (launcher integration)
│       │   └── custom.d.ts          TypeScript type declarations
│       ├── style/
│       │   ├── index.css            Stylesheet (required by build)
│       │   └── icons/
│       │       └── codeserver.svg   Code Server launcher icon
│       └── sagemaker_jproxy_launcher_ext/
│           ├── __init__.py          Python init, registers labextension
│           ├── _version.py          Version from package.json
│           └── labextension/
│               └── package.json     Extension manifest (rebuilt on install)
└── README.md                        This file
```

---

## Deployment

### Prerequisites

- SageMaker Notebook Instance with Docker available
- Terminal access
- **Minimum `ml.t3.large` (8 GB RAM).** The Docker container runs code-server,
  AI agent extensions (Cline, Claude Code), Python/Pylance, and mise runtimes
  concurrently. On `ml.t3.medium` (4 GB), the OOM killer will crash the
  container. **Recommended: `ml.r5.large` (16 GB)** for comfortable use with
  multiple AI agents active.

### Option A: Lifecycle Configuration (Recommended)

Attach the following lifecycle scripts in the SageMaker Notebook Instance console.

**Create script:**

```bash
#!/bin/bash
set -euo pipefail
sudo -u ec2-user -i <<'EOF'
set -euo pipefail
RC_ROOT=/home/ec2-user/SageMaker/RuntimeCommandDev/src/RuntimeCommand
mkdir -p "$(dirname "${RC_ROOT}")"
git clone https://github.com/gaotako/RuntimeCommand "${RC_ROOT}"
nohup bash "${RC_ROOT}/sagemaker/lifecycle/notebook_instance/create.sh" \
    > /home/ec2-user/SageMaker/lifecycle-create.log 2>&1 &
EOF
```

**Start script:**

```bash
#!/bin/bash
set -euo pipefail
sudo -u ec2-user -i <<'EOF'
set -euo pipefail
RC_ROOT=/home/ec2-user/SageMaker/RuntimeCommandDev/src/RuntimeCommand
nohup bash "${RC_ROOT}/sagemaker/lifecycle/notebook_instance/start.sh" \
    > /home/ec2-user/SageMaker/lifecycle-start.log 2>&1 &
EOF
```

> **Note:** SageMaker lifecycle scripts have a **5-minute timeout**. Both scripts
> use `nohup ... &` to run in the background and avoid the timeout. During
> setup, terminals show "Code Server is configuring" instead of errors. Once
> complete, the normal Docker entry hint appears. Check progress with
> `tail -f ~/SageMaker/lifecycle-create.log` or `lifecycle-start.log`.

The create script runs once to build the Docker image and install everything.
The start script runs on every start to reload the cached image and
re-register with Jupyter (since the root volume is ephemeral).

### Option B: Manual Steps

#### Step 1: Install Code-Server

```bash
bash sagemaker/install.sh
```

This builds the Docker image (`code-server-sagemaker:latest`), **saves it to
`~/SageMaker/CodeServerDockerImage/`** for persistence across notebook restarts,
and places a wrapper script at `${CODE_SERVER_APPLICATION}/bin/code-server` that
transparently runs code-server inside the container.

To pin a specific code-server version:

```bash
CODE_SERVER_VERSION=4.109.2 bash sagemaker/install.sh
```

#### Step 2: Register with Jupyter

```bash
bash sagemaker/setup_jupyter.sh
```

This adds the `c.ServerProxy.servers` configuration to `jupyter_notebook_config.py`,
installs the JupyterLab launcher extension, and copies the launcher icon.

#### Step 3: Restart Jupyter

In JupyterLab: **File → Shut Down**, then re-open the notebook URL.

Code Server will appear in the JupyterLab launcher under the "Other" category.

---

## Updating Code-Server

Rebuild the Docker image with the new version:

```bash
RC_ROOT=/home/ec2-user/SageMaker/RuntimeCommandDev/src/RuntimeCommand
FORCE_BUILD=1 bash "${RC_ROOT}/build.sh" <VERSION>
```

Use `FORCE_BUILD=1` to skip loading the cached image and force a fresh build.
The wrapper script does not need to change — it always uses the
`code-server-sagemaker:latest` image tag.

After rebuilding, the running container still uses the **old** image. To apply
the new image:

```bash
docker rm -f code-server-sagemaker
```

Then restart Jupyter: **File → Shut Down**, re-open the notebook URL, and open
Code Server from the launcher. The wrapper will create a new container from the
updated image.

## Image Persistence

Docker images are stored in Docker's data root (`/var/lib/docker/`), which lives
on the **ephemeral root volume** of SageMaker Notebook Instances. When a notebook
is stopped and restarted, the root volume is wiped and all Docker images are lost.

To avoid rebuilding on every restart, `build.sh` automatically:

1. **Saves** the built image to `~/SageMaker/CodeServerDockerImage/` (persistent EBS volume)
2. **Loads** the saved image on subsequent runs instead of rebuilding

This means the first install takes a few minutes to build, but subsequent restarts
only need a fast `docker load` (~10s).

| Variable           | Default                             | Description                   |
| ------------------ | ----------------------------------- | ----------------------------- |
| `DOCKER_IMAGE_DIR` | `~/SageMaker/CodeServerDockerImage` | Persistent image storage path |
| `FORCE_BUILD`      | *(unset)*                           | Set to `1` to force a rebuild |

---

## How It Works

### Docker Wrapper

The wrapper script (`sagemaker/wrapper.sh`) replaces the native code-server binary.
When jupyter-server-proxy invokes `${CODE_SERVER_APPLICATION}/bin/code-server`, the
wrapper:

1. Creates an isolated home directory at `~/SageMaker/CodeServerDockerHome/`
2. Rewrites `--bind-addr 127.0.0.1:{port}` to `0.0.0.0:{port}` inside the container
3. Maps the port back to `127.0.0.1` on the host via `-p`
4. Runs the container with `--security-opt label:disable` (SELinux compatibility)
5. Runs without `-u` flag (Docker user namespace remapping on SageMaker maps host
   uid 1000 to container uid 0)

### JupyterLab Extension

The `sagemaker_jproxy_launcher_ext` extension (v0.3.0, JupyterLab 4) queries the
`jupyter-server-proxy` API and creates launcher cards for registered proxy servers.
It builds from TypeScript source on every `pip install`.

---

## Troubleshooting

| Problem                    | Solution                                                     |
| -------------------------- | ------------------------------------------------------------ |
| Docker not found           | Ensure Docker is installed and `docker` is in PATH           |
| Permission denied on mkdir | Expected on first run; wrapper creates dirs automatically    |
| Port conflict              | `docker rm -f code-server-sagemaker`                         |
| Timeout on open            | Timeout is 120s; container startup takes ~10s                |
| Broken launcher icon       | Re-run `bash sagemaker/setup_jupyter.sh` and restart Jupyter |