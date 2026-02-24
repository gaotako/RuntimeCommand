# Docker image for code-server on SageMaker.
#
# Builds an Ubuntu-based image with code-server pre-installed. The image
# uses zsh as the default shell and includes common development tools.
#
# Args
# ----
# - CODE_SERVER_VERSION
#     Version of code-server to install (default: `latest`).
#
# Returns
# -------
# (No-Returns)
#
# Notes
# -----
# The image is built by `build.sh` and persisted to `DOCKER_IMAGE_DIR` via
# `docker save`. On subsequent runs `build.sh` loads the cached image via
# `docker load` to avoid rebuilding after SageMaker restarts.
#
# Examples
# --------
# ```
# docker build -t code-server-sagemaker .
# docker build -t code-server-sagemaker --build-arg CODE_SERVER_VERSION=4.109.2 .
# ```

# Base image.
FROM ubuntu:22.04

# code-server version build argument.
ARG CODE_SERVER_VERSION=latest

# Install system dependencies, development tools, and Python (system fallback).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        git \
        bash \
        zsh \
        python3 \
        ca-certificates \
        procps \
        openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Set zsh as the default shell.
RUN chsh -s /bin/zsh

# Install code-server (version determined by CODE_SERVER_VERSION build arg).
RUN if [ "${CODE_SERVER_VERSION}" = "latest" ]; then \
        curl -fsSL https://code-server.dev/install.sh | sh; \
    else \
        curl -fsSL https://code-server.dev/install.sh | sh -s -- --version "${CODE_SERVER_VERSION}"; \
    fi

# Verify code-server installation.
RUN code-server --version

# Copy and set the entrypoint script.
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Default entrypoint (interactive shell; code-server via flags).
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
