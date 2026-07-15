# Hardened RabbitMQ Server (v4.3.2)

A maximum-hardened, production-grade RabbitMQ container image based on **Alpine Linux 3.24**. Designed with zero-trust principles for secure enterprise environments.

## Highlights & Hardening Features

- **Interactive Shell Access Blocked:** Standard shells are removed. `/bin/sh` is wrapper-managed to block interactive shell invocation (e.g. `docker exec -it sh` returns `Interactive shell access is disabled.`), while preserving script-execution capabilities for RabbitMQ.
- **Immutable Application Binaries:** All RabbitMQ binaries are owned by `0:0` (root) and cannot be modified by the container execution process.
- **Run as Non-Root:** Container execution runs under UID/GID `999` (`rabbitmq` user), with a disabled login shell (`/sbin/nologin`).
- **Minimal Footprint:** No package manager (`apk`) or compilers included in the final stage.
- **Read-Only Root Filesystem Compatible:** Configured to easily support `read_only: true` container runtime options.

## Quick Start (Docker Compose)

```yaml
services:
  rabbitmq:
    image: hmtanbir/rabbitmq:latest
    container_name: rabbitmq
    ports:
      - "127.0.0.1:5672:5672"
      - "127.0.0.1:15672:15672"
    environments:
      - RABBITMQ_DEFAULT_USER: guest
      - RABBITMQ_DEFAULT_PASS: guest
      - RABBITMQ_ERLANG_COOKIE: securecookie456
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    restart: unless-stopped

    # --- Security hardening ---
    read_only: true
    tmpfs:
      - /tmp
      - /var/run/rabbitmq

    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true

    deploy:
      resources:
        limits:
          memory: 1G
          cpus: "2.0"

    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  rabbitmq_data:
    driver: local

```

## Quick Start (Docker CLI)

You can run the hardened RabbitMQ container directly using the `docker run` command:

```bash
docker run -d \
  --name rabbitmq \
  -p 127.0.0.1:5672:5672 \
  -p 127.0.0.1:15672:15672 \
  -e RABBITMQ_DEFAULT_USER=guest \
  -e RABBITMQ_DEFAULT_PASS=guest \
  -e RABBITMQ_ERLANG_COOKIE=securecookie456 \
  -v rabbitmq_data:/var/lib/rabbitmq \
  --read-only \
  --tmpfs /tmp \
  --tmpfs /var/run/rabbitmq \
  --cap-drop=ALL \
  --security-opt no-new-privileges:true \
  --restart unless-stopped \
  hmtanbir/rabbitmq:latest
```

## Supported Environment Variables

- `RABBITMQ_DEFAULT_USER`: Admin user name (defaults to `guest`).
- `RABBITMQ_DEFAULT_PASS`: Admin user password (defaults to `guest`).
- `RABBITMQ_ERLANG_COOKIE`: Erlang cookie to secure cluster communication.
- `RABBITMQ_CONF_ENV_FILE`: Custom configurations environment file (defaults to `/etc/rabbitmq/rabbitmq-env.conf`).
