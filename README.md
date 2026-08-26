# Devcontainers
Seamless sharing and version-control for your dev containers.

## Installation
`.devcontainer/` should not exist yet. This repo is intended to be a submodule at `.devcontainer/` and contain all dev containers for a project.
```bash
git submodule add git@github.com:ReubenBeeler/devcontainers.git .devcontainer/
```

## Variants
| Variant | Base | Notes |
| --- | --- | --- |
| `ubuntu/` | prebuilt `localhost:5001/ubuntu` | Built AOT. A minimal container for faster devcontainer development and testing. |
| `ubuntu-flutter/` | prebuilt `localhost:5001/ubuntu-flutter` | Built AOT. Flutter, Android SDK + emulator, headless desktop. |

## Prebuilt images
Both variants bake their dependencies into a Docker image
instead of installing them on every container create. The image is built once
and served from a local registry at `localhost:5001`, so opening the container
is fast after the first time.

The scripts that manage this live in `scripts/` and are shared by every
variant. A variant is identified by the directory holding its `Dockerfile`;
that directory is both the build context and — via its basename — the image
name.

```bash
# Rebuild after editing a Dockerfile, then reopen the container
bash scripts/rebuild-and-push.sh ubuntu-flutter

# Build only if the image is missing (what each initialize.sh calls)
bash scripts/ensure-image.sh ubuntu-flutter

# Manage the shared registry container
bash scripts/setup-local-registry.sh list
bash scripts/setup-local-registry.sh add local-registry
bash scripts/setup-local-registry.sh remove local-registry
```

`REGISTRY`, `IMAGE_NAME` and `TAG` can be overridden via the environment.

`scripts/setup-dbus-keyring.sh` is likewise shared: it pins one D-Bus session bus
and keeps gnome-keyring's Secret Service unlocked for libsecret clients.

## Notes
Don't look in `.devcontainer/`... it is a symlink to allow the dev containers extension to see the repo-level dev containers. The dev containers are repo-level to enable use as a submodule -- see [Installation](#installation).
