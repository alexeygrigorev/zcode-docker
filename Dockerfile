# syntax=docker/dockerfile:1.7

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive

# Zcode's manifest gives a SHA-512 digest for the current release. Download it
# during the build and verify it before the package is unpacked.
COPY scripts/download-zcode-release.sh /usr/local/bin/download-zcode-release

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        dbus-x11 \
        fluxbox \
        fonts-dejavu-core \
        fonts-noto-color-emoji \
        git \
        gnupg \
        iproute2 \
        jq \
        libasound2t64 \
        libnotify4 \
        libsecret-1-0 \
        libnss3 \
        libxss1 \
        libxtst6 \
        libatspi2.0-0t64 \
        libuuid1 \
        openssh-client \
        procps \
        python3 \
        python3-yaml \
        python3-websockify \
        ripgrep \
        sudo \
        tini \
        tmux \
        x11-utils \
        x11vnc \
        xdg-utils \
        epiphany-browser \
        xterm \
        xvfb \
    && rm -rf /var/lib/apt/lists/* \
    && download-zcode-release --asset deb --out /tmp/zcode-install \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/zcode-install/ZCode-*.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/zcode-install \
    && chmod 0755 /opt/ZCode/chrome-sandbox

RUN apt-get update \
    && apt-get install -y --no-install-recommends wget ca-certificates \
    && wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/google-chrome.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/google-chrome.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/google-chrome.deb

RUN apt-get update \
    && apt-get install -y --no-install-recommends xdotool \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get install -y --no-install-recommends xdotool \
    && rm -rf /var/lib/apt/lists/* \
    && wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/google-chrome.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/google-chrome.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/google-chrome.deb

RUN apt-get update \
    && apt-get install -y --no-install-recommends novnc \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=0644 config/fluxbox-menu /usr/local/share/zcode-docker/fluxbox-menu
COPY --chmod=0755 container-entrypoint.sh /usr/local/bin/zcode-container-entrypoint

RUN chmod 0755 /usr/local/share/zcode-docker

RUN install -d -o 1000 -g 1000 -m 0755 /home/zcode

# Build-time user. Compose overrides it with the host UID/GID at runtime.
USER 1000:1000
WORKDIR /home/zcode

EXPOSE 6080 5900

HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=12 \
  CMD curl --fail --silent --show-error "http://127.0.0.1:${VNC_PORT:-6080}/vnc.html" >/dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/zcode-container-entrypoint"]
