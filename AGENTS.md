# EasyKind - Agent Guide

## What this repo is
Bash scripts to set up a local Kind (Kubernetes-in-Docker) cluster on Linux with Docker, kind, kubectl, helm, and optional kube-vip as a LoadBalancer. Designed to be installed via `bootstrap.sh` and run with `main`.

## Install / entrypoints
- Bootstrap: `./bootstrap.sh` (requires sudo; installs Go/gum, sets inotify limits, copies scripts to `/usr/local/bin` and assets to `/usr/local/share/easykind`, adds Go bin to PATH in `~/.bashrc`).
- CLI menu: `main` (installed to PATH). Sources `scripts/common`, `install_binaries`, `create_cluster`, `kube_vip`, `delete_cluster`, `cleanup`. Requires `gum`. Shows menu: Install binaries → Create cluster → Install kube-vip → Delete cluster → Cleanup → Exit.
- Templates: `script_template` shows pattern (source `common`, define function, run if executed directly).

## Commands (exact)
**From repo root (dev):** scripts can be run directly if dependencies present. Each script supports being sourced or executed directly (checks `BASH_SOURCE[0] == "$0"`).
- `./scripts/install_binaries` - installs docker (via get.docker.com), kind via `go install sigs.k8s.io/kind@v0.33.0` (needs Go), kubectl (downloads latest stable from dl.k8s.io for detected arch), helm (via get-helm-3 script), adds `alias k='kubectl'` to `~/.bashrc`.
- `./scripts/create_cluster` - prompts for cluster name; if exists, returns early. Looks for cluster config via `cluster_config_path()`: checks `KIND_CLUSTER_CONFIG` env var first, then `scripts/../assets/config-cluster.yaml`, then `/usr/local/share/easykind/assets/config-cluster.yaml`. Prompts to retain failed nodes (`--retain`). Runs `kind create cluster --name ... --config ... [--retain]`.
- `./scripts/kube_vip` - prompts for cluster name (must exist). Gets latest kube-vip release from GitHub API (or `KUBE_VIP_VERSION`). Determines LoadBalancer range from `docker network inspect kind` (16-bit -> `a.b.100.10-a.b.100.30`, 24-bit -> `a.b.c.100-a.b.c.130`); else prompts. Installs cloud controller, creates ConfigMap `kubevip` in `kube-system` with `range-global`, applies RBAC, deploys daemonset via `docker run ghcr.io/kube-vip/kube-vip:${kv_version} manifest daemonset --services --inCluster --arp --interface eth0`, waits for rollout.
- `./scripts/delete_cluster` - prompts for name with retry if not found; confirms before `kind delete cluster`.
- `./scripts/cleanup` - prompts to remove installed scripts (`main,install_binaries,create_cluster,kube_vip,delete_cluster,cleanup,common`) from `/usr/local/bin` and assets from `/usr/local/share/easykind`.

## Gotchas / repo-specific facts
- `bootstrap.sh` removes legacy `${BIN_DIR}/install` if present (conflicts with system install). Copies all files from `scripts/*` (only files) to `/usr/local/bin` with +x. Copies all files from `assets/*` to `${SHARE_DIR}/assets/`.
- `main` requires `gum` installed; exits if missing. Sources scripts in order.
- `install_binaries` adds `export PATH="$(go env GOPATH)/bin:${PATH}"` if go present; `main` also does this. Adds `alias k='kubectl'` to `~/.bashrc` and sources it.
- `create_cluster` will not recreate existing cluster (just logs and returns). Config file is expected but not present in repo under `assets/` in current checkout - must come from assets dir or `KIND_CLUSTER_CONFIG`.
- `kube_vip` uses `docker network inspect kind` to infer range; requires docker running and kind network existing. Deploys with `--interface eth0` (hardcoded). Uses `kubectl --context kind-${cluster_name}`.
- Logging via `log_info/warn/error` from `common` with timestamps/colors.
- All scripts use `set -euo pipefail`. When sourced, they define functions; when executed directly, they source `common` and run the main function.

## Conventions
- Scripts are modular: shared helpers in `common`. Follow `script_template` pattern for new scripts (define function, guard for direct execution).
- Prefer using `request_user_input` from `common` for prompts requiring non-empty input.
- No tests, linters, formatters, CI, or package manifests present.
