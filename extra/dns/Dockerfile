# ==============================================================================
#   CHARIZARD DNS - Unbound Recursive Resolver
#   Debian Stable Slim + Unbound
#   Developed by Sanvil (c) 2025
# ==============================================================================

FROM debian:stable-slim

LABEL maintainer="Charizard"
LABEL description="Unbound DNS Recursive Resolver"
LABEL version="1.0"

# Install Unbound and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    unbound \
    unbound-anchor \
    dns-root-data \
    ca-certificates \
    curl \
    dnsutils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /etc/unbound/unbound.conf.d \
    && mkdir -p /var/log/unbound \
    && chown -R unbound:unbound /var/log/unbound

# Initialize DNSSEC root trust anchor
RUN unbound-anchor -a /var/lib/unbound/root.key || true

# Download root hints
RUN curl -s https://www.internic.net/domain/named.root \
    -o /etc/unbound/root.hints

# Generate unbound-control certificates
RUN unbound-control-setup -d /etc/unbound 2>/dev/null \
    && chown unbound:unbound /etc/unbound/*.pem 2>/dev/null || true

# Copy configuration
COPY config/unbound.conf /etc/unbound/unbound.conf

# Expose DNS port
EXPOSE 53/udp 53/tcp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD dig @127.0.0.1 -p 53 cloudflare.com +short +time=5 || exit 1

# Start Unbound in foreground
CMD ["unbound", "-d", "-v"]
