# syntax=docker/dockerfile:1

# Image for the OpenViking Open WebUI tool server:
# https://github.com/volcengine/OpenViking/tree/main/examples/openwebui-plugin

ARG PYTHON_VERSION=3.12

# --- source: fetch only the plugin directory from upstream -------------------
FROM alpine/git:latest AS source
ARG OV_REPO=https://github.com/volcengine/OpenViking.git
# Branch, tag or commit SHA to build from
ARG OV_REF=main
WORKDIR /src
# Sparse, blob-less checkout: the full OpenViking repo is large, and only
# examples/openwebui-plugin is needed. Fetching by ref also works for SHAs.
RUN git init -q . \
 && git remote add origin "${OV_REPO}" \
 && git sparse-checkout set examples/openwebui-plugin \
 && git fetch -q --depth 1 --filter=blob:none origin "${OV_REF}" \
 && git checkout -q FETCH_HEAD \
 && git rev-parse HEAD > examples/openwebui-plugin/.upstream-commit

# --- builder: build a wheel and install it into a virtualenv -----------------
FROM python:${PYTHON_VERSION}-slim AS builder
ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /build
COPY --from=source /src/examples/openwebui-plugin/ .
RUN python -m venv /opt/venv \
 && /opt/venv/bin/pip install .

# --- test: run the upstream test suite (docker build --target test .) --------
FROM builder AS test
RUN /opt/venv/bin/pip install ".[test]" \
 && /opt/venv/bin/python -m pytest tests -q

# --- runtime ------------------------------------------------------------------
FROM python:${PYTHON_VERSION}-slim AS runtime
ARG OV_REF=main

LABEL org.opencontainers.image.title="openviking-openwebuiplugin" \
      org.opencontainers.image.description="OpenViking OpenAPI tool server for Open WebUI" \
      org.opencontainers.image.source="https://github.com/volcengine/OpenViking/tree/main/examples/openwebui-plugin" \
      org.opencontainers.image.licenses="AGPL-3.0" \
      org.opencontainers.image.version="${OV_REF}"

ENV PATH=/opt/venv/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    OV_ENDPOINT=http://openviking:1933 \
    OV_BIND=0.0.0.0:8765

RUN useradd --system --uid 10001 --no-create-home --shell /usr/sbin/nologin app
COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /build/.upstream-commit /opt/venv/.upstream-commit

USER app
EXPOSE 8765

# No curl in slim images; use the Python stdlib. Reads the port from OV_BIND.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import os,urllib.request; p=os.environ.get('OV_BIND','0.0.0.0:8765').rpartition(':')[2] or '8765'; urllib.request.urlopen(f'http://127.0.0.1:{p}/health', timeout=4)"]

CMD ["openviking-openwebui"]
