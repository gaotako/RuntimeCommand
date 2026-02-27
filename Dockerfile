# Docker image for code-server on SageMaker.
#
# Builds an Ubuntu-based image with code-server pre-installed. The image
# uses zsh as the default shell and includes common development tools.
#
# Args
# ----
# - `CODE_SERVER_VERSION`
#     Version of code-server to install (default: `"latest"`).
# - `DOCKER_SHELL`
#     Default shell for the container (default: `"/bin/zsh"`).
#
# Returns
# -------
# (No-Returns)
#
# Notes
# -----
# The image includes: zsh, git, vim, tmux, less, curl, unzip, openssh-client,
# python3, AWS CLI v2, code-server, and mise (polyglot runtime manager).
#
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

# Build arguments.
ARG CODE_SERVER_VERSION=latest
ARG DOCKER_SHELL=/bin/zsh

# Install system dependencies, development tools, and Python (system fallback).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        git \
        bash \
        zsh \
        python3 \
        python3-pip \
        ca-certificates \
        procps \
        openssh-client \
        less \
        vim \
        tmux \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# Set the default shell.
RUN chsh -s ${DOCKER_SHELL}

# Create `python` symlink (Ubuntu 22.04 only has `python3`).
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Install code-server (version determined by CODE_SERVER_VERSION build arg).
RUN if [ "${CODE_SERVER_VERSION}" = "latest" ]; then \
        curl -fsSL https://code-server.dev/install.sh | sh; \
    else \
        curl -fsSL https://code-server.dev/install.sh | sh -s -- --version "${CODE_SERVER_VERSION}"; \
    fi

# Verify code-server installation.
RUN code-server --version

# Install AWS CLI v2.
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/awscliv2.zip /tmp/aws

# Verify AWS CLI installation.
RUN aws --version

# Install mise (polyglot runtime manager).
RUN curl -fsSL https://mise.run | sh
RUN /root/.local/bin/mise --version
RUN cp /root/.local/bin/mise /usr/local/bin/mise

# Copy and set the entrypoint script.
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Default entrypoint (interactive shell; code-server via flags).
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
