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
    image: yourusername/rabbitmq:latest
    container_name: rabbitmq
    ports:
      - "127.0.0.1:5672:5672"
      - "127.0.0.1:15672:15672"
    environment:
      - RABBITMQ_DEFAULT_USER=admin
      - RABBITMQ_DEFAULT_PASS=securepassword123
      - RABBITMQ_ERLANG_COOKIE=securecookie456
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    read_only: true
    tmpfs:
      - /tmp
      - /var/run/rabbitmq
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    restart: unless-stopped

volumes:
  rabbitmq_data:
```

## Supported Environment Variables

- `RABBITMQ_DEFAULT_USER`: Admin user name (defaults to `guest`).
- `RABBITMQ_DEFAULT_PASS`: Admin user password (defaults to `guest`).
- `RABBITMQ_ERLANG_COOKIE`: Erlang cookie to secure cluster communication.
- `RABBITMQ_CONF_ENV_FILE`: Custom configurations environment file (defaults to `/etc/rabbitmq/rabbitmq-env.conf`).
