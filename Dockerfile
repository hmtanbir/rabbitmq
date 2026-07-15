# Step 1: Use a temporary build image to download and extract the RabbitMQ release
FROM dhi.io/debian-base:trixie-debian13-dev AS builder

# Install curl, ca-certificates, tar, and xz-utils
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    tar \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Set RabbitMQ version to download
ARG RABBITMQ_VERSION=4.3.2

# Download, verify, and extract the generic UNIX binary release
ARG RABBITMQ_SHA256=881cbdd22231c3879e45a58d79a83d69c6604d0e291ff6dec2d9e7ab649b119e
RUN set -euo pipefail \
    && curl -fSL "https://github.com/rabbitmq/rabbitmq-server/releases/download/v${RABBITMQ_VERSION}/rabbitmq-server-generic-unix-${RABBITMQ_VERSION}.tar.xz" -o /tmp/rabbitmq.tar.xz \
    && echo "${RABBITMQ_SHA256}  /tmp/rabbitmq.tar.xz" | sha256sum -c - \
    && tar -xJf /tmp/rabbitmq.tar.xz -C / \
    && mv /rabbitmq_server-${RABBITMQ_VERSION} /rabbitmq \
    && rm /tmp/rabbitmq.tar.xz

# Remove unnecessary documentation and sources to optimize size
RUN rm -rf /rabbitmq/share \
    && rm -rf /rabbitmq/LICENSE* /rabbitmq/INSTALL

# Step 2: Use standard Alpine to install Erlang and extract dependencies
FROM alpine:3.20 AS alpine-builder

RUN apk add --no-cache \
    erlang \
    openssl \
    ncurses-libs \
    libstdc++ \
    gcc \
    musl-dev

# Create a clean staging directory for Erlang and libraries
RUN mkdir -p /staging/usr/bin /staging/usr/lib /staging/lib /staging/bin
RUN cp -R /usr/lib/erlang /staging/usr/lib/
RUN cp /usr/bin/erl /usr/bin/erlc /staging/usr/bin/
RUN cp -d /lib/libcrypto* /lib/libssl* /lib/libz* /staging/lib/
RUN cp -d /usr/lib/libcrypto* /usr/lib/libssl* /usr/lib/libncurses* /usr/lib/libstdc++* /usr/lib/libgcc_s* /staging/usr/lib/

# Compile a shell wrapper that blocks interactive shell execution (when argc <= 1)
# but allows script execution by forwarding to /bin/real_sh.
RUN ln -s /bin/busybox /staging/bin/real_sh \
    && echo '#include <stdio.h>' > /tmp/wrapper.c \
    && echo '#include <unistd.h>' >> /tmp/wrapper.c \
    && echo 'int main(int argc, char *argv[]) {' >> /tmp/wrapper.c \
    && echo '    if (argc <= 1) {' >> /tmp/wrapper.c \
    && echo '        fprintf(stderr, "Interactive shell access is disabled.\\n");' >> /tmp/wrapper.c \
    && echo '        return 1;' >> /tmp/wrapper.c \
    && echo '    }' >> /tmp/wrapper.c \
    && echo '    execv("/bin/real_sh", argv);' >> /tmp/wrapper.c \
    && echo '    return 1;' >> /tmp/wrapper.c \
    && echo '}' >> /tmp/wrapper.c \
    && gcc -O2 /tmp/wrapper.c -o /staging/bin/sh \
    && cp /staging/bin/sh /staging/bin/ash

# Step 3: Combine everything on top of the hardened Alpine base
FROM dhi.io/alpine-base:3.24 AS combiner

USER 0

# Copy Erlang and libraries from the alpine-builder staging
COPY --from=alpine-builder /staging/ /

# Create rabbitmq system user and group (UID/GID 999) with no login shell
RUN addgroup -g 999 rabbitmq && \
    adduser -u 999 -G rabbitmq -h /var/lib/rabbitmq -s /sbin/nologin -H -D rabbitmq

# Remove bash to prevent shell access (ash is already replaced by the security wrapper)
RUN rm -f /bin/bash /usr/bin/bash || true

# Set up required directories with restrictive permissions
RUN mkdir -p /var/lib/rabbitmq /var/log/rabbitmq /etc/rabbitmq /var/run/rabbitmq \
    && chown -R rabbitmq:rabbitmq /var/lib/rabbitmq /var/log/rabbitmq /etc/rabbitmq /var/run/rabbitmq \
    && chmod 700 /var/lib/rabbitmq /var/log/rabbitmq /etc/rabbitmq /var/run/rabbitmq

# Copy RabbitMQ from the builder stage
COPY --from=builder /rabbitmq /usr/lib/rabbitmq

# Create symlinks for binary executables
RUN mkdir -p /usr/local/bin \
    && ln -s /usr/lib/rabbitmq/sbin/rabbitmq-server /usr/local/bin/rabbitmq-server \
    && ln -s /usr/lib/rabbitmq/sbin/rabbitmqctl /usr/local/bin/rabbitmqctl \
    && ln -s /usr/lib/rabbitmq/sbin/rabbitmq-plugins /usr/local/bin/rabbitmq-plugins \
    && ln -s /usr/lib/rabbitmq/sbin/rabbitmq-diagnostics /usr/local/bin/rabbitmq-diagnostics

# Set proper ownership for RabbitMQ files (read-only/immutable for rabbitmq user)
RUN chown -R 0:0 /usr/lib/rabbitmq \
    && chmod -R 755 /usr/lib/rabbitmq

# Enable the management plugin
RUN printf '[rabbitmq_management,rabbitmq_management_agent].\n' > /etc/rabbitmq/enabled_plugins \
    && chown 0:0 /etc/rabbitmq/enabled_plugins \
    && chmod 644 /etc/rabbitmq/enabled_plugins

# Create rabbitmq-env.conf to override SYS_PREFIX so data paths resolve to
# /var/lib/rabbitmq instead of /usr/lib/rabbitmq/var/lib/rabbitmq
RUN printf 'SYS_PREFIX=\n' > /etc/rabbitmq/rabbitmq-env.conf \
    && chown 0:0 /etc/rabbitmq/rabbitmq-env.conf \
    && chmod 644 /etc/rabbitmq/rabbitmq-env.conf

# Step 4: Build the final hardened Alpine image
FROM dhi.io/alpine-base:3.24

LABEL maintainer="hmtanbir" \
      version="4.3.2" \
      description="Hardened RabbitMQ server with shell access disabled"

# Copy everything from combiner to keep it pristine and minimal
COPY --from=combiner / /

USER 0

# Ensure directory permissions are correctly preserved for rabbitmq user in the final image layer
RUN mkdir -p /var/lib/rabbitmq/mnesia \
    && chown -R 999:999 /var/lib/rabbitmq /var/log/rabbitmq /etc/rabbitmq /var/run/rabbitmq \
    && chmod 700 /var/lib/rabbitmq /var/log/rabbitmq /etc/rabbitmq /var/run/rabbitmq

# Define environment variables
ENV PATH=/usr/lib/rabbitmq/sbin:/usr/lib/erlang/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    HOME=/var/lib/rabbitmq \
    RABBITMQ_LOGS=- \
    RABBITMQ_SASL_LOGS=- \
    RABBITMQ_CONF_ENV_FILE=/etc/rabbitmq/rabbitmq-env.conf

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD rabbitmq-diagnostics check_port_connectivity && rabbitmq-diagnostics check_running && rabbitmq-diagnostics check_local_alarms || exit 1

# Expose AMQP and Management ports
# (25672 Erlang distribution and 4369 EPMD are internal-only, not exposed)
EXPOSE 5672 15672

USER rabbitmq
WORKDIR /var/lib/rabbitmq

ENTRYPOINT ["rabbitmq-server"]
