FROM ubuntu:22.04

ARG CODE_SERVER_VERSION=latest

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        git \
        bash \
        ca-certificates \
        procps \
        openssh-client \
    && rm -rf /var/lib/apt/lists/*

RUN if [ "${CODE_SERVER_VERSION}" = "latest" ]; then \
        curl -fsSL https://code-server.dev/install.sh | sh; \
    else \
        curl -fsSL https://code-server.dev/install.sh | sh -s -- --version "${CODE_SERVER_VERSION}"; \
    fi

RUN code-server --version

ENTRYPOINT ["code-server"]