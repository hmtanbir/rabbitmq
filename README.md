# Hardened RabbitMQ Server

This repository contains a production-ready, maximum-hardened configuration for **RabbitMQ 4.3.2**. The image is designed on top of a secure Alpine Linux base, with strict limits on privileges, immutable files, and interactive shell execution disabled.

## Security Hardening Features

1. **Disabled Interactive Shells:**
   - Interactive shells (`/bin/ash`, `/bin/bash`, `/usr/bin/bash`) are completely removed or replaced.
   - `/bin/sh` and `/bin/ash` are replaced by a compiled C wrapper that detects interactive execution (`argc <= 1`) and blocks it instantly (`Interactive shell access is disabled.`), while safely forwarding legitimate script invocations (like the RabbitMQ runner itself) to a hidden shell.
2. **Immutable Binaries:**
   - The application binaries (`/usr/lib/rabbitmq`) are owned by `0:0` (root) and set to read/execute only (`755`). This prevents any running container process from overwriting, modifying, or appending malicious code to the server code.
3. **No-Login/No-Privilege System User:**
   - Runs as a dedicated non-root system user `rabbitmq` (UID/GID `999`) with a shell set to `/sbin/nologin`.
4. **Minimal Attack Surface:**
   - Built on `dhi.io/alpine-base:3.24`, which does not contain the `apk` package manager. This prevents packages from being dynamically added during runtime.
5. **Dropped Capabilities & Read-Only Filesystem:**
   - Ready to run with a read-only root filesystem (`read_only: true`), with ephemeral writes bound to designated `tmpfs` mounts (`/tmp`, `/var/run/rabbitmq`).
   - Drops all standard Linux capabilities (`cap_drop: [ALL]`) and restricts privilege escalation (`no-new-privileges:true`).

---

## Local Development

### Prerequisites
- Docker & Docker Compose

### Running locally
1. Create a `.env` file in the root directory (make sure not to commit this file):
   ```env
   RABBITMQ_DEFAULT_USER=guest
   RABBITMQ_DEFAULT_PASS=securepassword123
   RABBITMQ_ERLANG_COOKIE=securecookie456
   ```

2. Spin up the container:
   ```bash
   docker compose up -d --build
   ```

3. Verify running services:
   - AMQP Port: `127.0.0.1:5672`
   - Management UI: `http://127.0.0.1:15672`

4. Run diagnostics:
   ```bash
   docker compose exec rabbitmq rabbitmq-diagnostics check_running
   ```

---

## CI/CD Pipeline

The GitHub Actions workflow in `.github/workflows/deploy.yml` triggers on pushes to the `main` branch:
1. Builds the multi-platform Docker image (`linux/amd64` and `linux/arm64`).
2. Pushes the built image to Docker Hub.
3. Automatically updates the Docker Hub repository overview description using `README-DOCKER.md`.
