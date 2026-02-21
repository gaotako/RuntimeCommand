# Docker Code-Server for SageMaker

Run the latest code-server inside a Docker container on SageMaker Notebook Instances,
overcoming the AL2 glibc 2.26 limitation (code-server >= 4.17.0 requires glibc >= 2.28).

---

## File Structure

```
docker/
├── Dockerfile                       Ubuntu 22.04 + code-server image
├── build.sh                         Build the Docker image
├── wrapper.sh                       Drop-in replacement for the code-server binary
├── install.sh                       Install code-server (build + wrapper + verify)
├── setup_jupyter.sh                 Register code-server into JupyterLab launcher
├── README.md                        This file
└── sagemaker_jproxy_launcher_ext/   JupyterLab extension for server-proxy launcher
    ├── package.json                 NPM metadata and build scripts
    ├── pyproject.toml               Python build system config
    ├── setup.py                     Python package installer
    ├── setup.cfg                    Package metadata
    ├── install.json                 Package manager metadata
    ├── MANIFEST.in                  Distribution file list
    ├── tsconfig.json                TypeScript compiler config
    ├── LICENSE                      BSD-3-Clause license
    ├── TEST_PLAN.md                 Manual test plan for v0.3.0
    ├── src/
    │   ├── index.ts                 Extension source (launcher integration)
    │   └── custom.d.ts              TypeScript type declarations
    ├── style/
    │   └── icons/
    │       └── codeserver.svg       Code Server launcher icon
    └── sagemaker_jproxy_launcher_ext/
        ├── __init__.py              Python init, registers labextension
        ├── _version.py              Version from package.json
        └── labextension/
            └── package.json         Extension manifest (rebuilt on install)
```

---

## Deployment

### Prerequisites

- SageMaker Notebook Instance with Docker available
- Terminal access

### Step 1: Install Code-Server

```bash
bash docker/install.sh
```

This builds the Docker image (`code-server-sagemaker:latest`) and places a wrapper
script at `${CODE_SERVER_APPLICATION}/bin/code-server` that transparently runs
code-server inside the container.

To pin a specific code-server version:

```bash
CODE_SERVER_VERSION=4.109.2 bash docker/install.sh
```

### Step 2: Register with Jupyter

```bash
bash docker/setup_jupyter.sh
```

This adds the `c.ServerProxy.servers` configuration to `jupyter_notebook_config.py`,
installs the JupyterLab launcher extension, and copies the launcher icon.

### Step 3: Restart Jupyter

In JupyterLab: **File → Shut Down**, then re-open the notebook URL.

Code Server will appear in the JupyterLab launcher under the "Other" category.

---

## Updating Code-Server

Rebuild the Docker image with the new version:

```bash
bash docker/build.sh <VERSION>
```

The wrapper script does not need to change — it always uses the
`code-server-sagemaker:latest` image tag.

---

## How It Works

### Docker Wrapper

The wrapper script (`wrapper.sh`) replaces the native code-server binary. When
jupyter-server-proxy invokes `${CODE_SERVER_APPLICATION}/bin/code-server`, the wrapper:

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

| Problem                    | Solution                                                  |
| -------------------------- | --------------------------------------------------------- |
| Docker not found           | Ensure Docker is installed and `docker` is in PATH        |
| Permission denied on mkdir | Expected on first run; wrapper creates dirs automatically |
| Port conflict              | `docker rm -f code-server-sagemaker`                      |
| Timeout on open            | Timeout is 120s; container startup takes ~10s             |
| Broken launcher icon       | Re-run `bash docker/setup_jupyter.sh` and restart Jupyter |
