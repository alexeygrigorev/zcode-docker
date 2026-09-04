# Zcode in a browser

This runs Zcode Desktop in Docker and exposes its private X display through
noVNC, so it works without installing an X window system on the host. It uses
host networking for a direct loopback browser endpoint. It is modeled after
[switch-onboarding](https://github.com/alexeygrigorev/switch-onboarding),
but it uses the current host user and mounts that user's complete home directory
into the desktop session.

Zcode is installed during the image build from the official Zcode update
manifest. The manifest's SHA-512 digest and declared size are checked before
the `.deb` is installed.

## Security boundary

This is intentionally not a sandboxed onboarding container. It receives your
entire host home directory, so it can read and write all files there, including
SSH keys, browser cookies, API credentials, Git credentials, and Zcode state.
It runs as your UID/GID with Docker's default seccomp profile disabled so the
authentication browser can operate normally; the container is not privileged.

The noVNC endpoint has no password. The listener is restricted to host loopback
by default. Do not change
`VNC_BIND_ADDRESS` to `0.0.0.0`; any local process that can reach loopback can
view and control the desktop.

## Run

From this directory as your normal user:

```bash
./scripts/dev.sh
```

Then open:

<http://127.0.0.1:6180/vnc.html?autoconnect=1&resize=scale>

The script uses the current UID/GID and `$HOME`, and refuses to run as root.
To use another loopback port:

```bash
ZCODE_NOVNC_PORT=6280 ./scripts/dev.sh
```

The default Zcode working directory inside the desktop is your home directory.
Open a terminal or Google Chrome from the Fluxbox menu for shell or
authentication work. Because `/home/zcode` is your real home, configuration
written by the GUI appears directly in host paths.

## Operations

```bash
./scripts/dev.sh ps
./scripts/dev.sh logs --follow
./scripts/dev.sh down
```

The root filesystem is writable because Electron/Chromium update and cache
behavior varies by release. `/tmp`, `/run`, and the user runtime directory are
container-private tmpfs mounts. Home state is not container-private.

If another service already uses port 6180, set a different
`ZCODE_NOVNC_PORT`; the script checks before starting the stack.
