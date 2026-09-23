# openviking-openwebui (Docker)

Docker image for the [OpenViking Open WebUI tool server](https://github.com/volcengine/OpenViking/tree/main/examples/openwebui-plugin):
a small FastAPI server that exposes a curated set of OpenViking endpoints
(`ov_search`, `ov_recall_memories`, `ov_add_memory`, `ov_list_memories`,
`ov_read_resource`, `ov_add_resource`, `ov_session_status`) as OpenAPI tools
that Open WebUI discovers from `/openapi.json`.

This repository contains no plugin code. The Dockerfile fetches it from
upstream at build time.

## Build

```bash
docker build -t openviking-openwebui .

# Pin to an upstream branch, tag or commit
docker build --build-arg OV_REF=03391bae4335eacf440a62d942f3951de6a63cbe -t openviking-openwebui .

# Run the upstream test suite inside the build
docker build --target test .
```

| Build arg | Default | Description |
| --- | --- | --- |
| `OV_REF` | `main` | Upstream branch, tag or commit SHA to build |
| `OV_REPO` | `https://github.com/volcengine/OpenViking.git` | Upstream repository (for forks) |
| `PYTHON_VERSION` | `3.12` | Python base image version |

The upstream commit that was built is recorded in `/opt/venv/.upstream-commit`
inside the image.

## Run

```bash
cp .env.example .env   # then set OV_ENDPOINT / OV_API_KEY
docker compose up -d
curl http://localhost:8765/health
```

Or without compose:

```bash
docker run -d --name openviking-openwebui -p 127.0.0.1:8765:8765 \
  -e OV_ENDPOINT=http://openviking:1933 -e OV_API_KEY=... \
  acaranta/openviking-openwebui
```

Then in Open WebUI, go to **Settings → Tools → Add Tool Server** and enter
the URL where the container can be reached (e.g. `http://openviking-openwebui:8765`
when both run on the same Docker network).

## Configuration

All settings are environment variables read by the upstream server:

| Variable | Image default | Description |
| --- | --- | --- |
| `OV_ENDPOINT` | `http://openviking:1933` | OpenViking server base URL |
| `OV_API_KEY` | _(empty)_ | Sent as `Authorization: Bearer …` |
| `OV_ACCOUNT` | `default` | Sent as `X-OpenViking-Account` |
| `OV_USER` | `default` | Sent as `X-OpenViking-User` |
| `OV_AGENT` | `default` | Sent as `X-OpenViking-Actor-Peer` |
| `OV_BIND` | `0.0.0.0:8765` | Listen address (the healthcheck follows its port) |
| `OV_TIMEOUT` | `30` | Timeout in seconds for calls to OpenViking |

The server handles one tenant per process. Run one container per
`(account, user)` pair if you need several.

## Security

The tool server has **no authentication of its own**. Anyone who can reach
it can act on the configured tenant's data with the configured API key.
Publish it only on localhost or a private network, or put an
authenticating proxy in front of it. The container runs as a non-root user.

## CI

`.drone.yml` uses the `docker-build-multiarch.yaml` Drone template and builds
`linux/amd64` and `linux/arm64/v8`. It pushes to both the private registry
(`ai/openviking-openwebui`) and Docker Hub (`openviking-openwebui`).

## License

The upstream plugin is AGPL-3.0 (© Beijing Volcano Engine Technology Co., Ltd.),
and so is the image built from it.
