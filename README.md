# EasyKind

A simple set of Bash scripts to spin up a local [Kind](https://kind.sigs.k8s.io/) (Kubernetes-in-Docker) cluster on Linux, install common CLI tools, install [Calico](https://www.tigera.io/project-calico/) as the CNI, and optionally set up [kube-vip](https://kube-vip.io/) as a LoadBalancer.

## What it installs

- [Docker](https://docs.docker.com/) (via [get.docker.com](https://get.docker.com))
- [kind](https://kind.sigs.k8s.io/) `v0.33.0` (via `go install`)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/) (latest stable from dl.k8s.io, arch-aware)
- [Helm](https://helm.sh/) (via get-helm-3)
- [gum](https://github.com/charmbracelet/gum) (for the interactive CLI)
- Go (if missing) and inotify limits tuned for Kind
- [Calico](https://www.tigera.io/project-calico/) as a policy-capable CNI (required by the included cluster config)
- Optional: [kube-vip](https://kube-vip.io/) for LoadBalancer services

## Prerequisites

- Linux (tested on Debian/Ubuntu-like distros)
- `sudo` privileges
- Docker available or willing to be installed
- Network access to download binaries and manifests

## Installation

```bash
git clone https://github.com/your-org/easykind.git
cd easykind
./bootstrap.sh
```

What `bootstrap.sh` does:
- Installs Go and gum (if missing)
- Increases inotify limits (`fs.inotify.max_user_instances=1024`, `fs.inotify.max_user_watches=1048576`) and persists in `/etc/sysctl.d/99-easykind.conf`
- Adds Go bin (`$(go env GOPATH)/bin`) to `~/.bashrc` PATH
- Removes legacy `/usr/local/bin/install` if present
- Copies `scripts/*` to `/usr/local/bin` with `+x`
- Copies `assets/*` to `/usr/local/share/easykind/assets/`
- Prompts you to run `main`

## Usage

After bootstrap, run the interactive menu from any terminal:

```bash
main
```

The menu walks you through:
1. **Install binaries** - Docker, kind, kubectl, helm, adds `alias k='kubectl'` to `~/.bashrc`
2. **Create cluster** - Prompts for cluster name, uses a Kind config, optional `--retain` for failed nodes
3. **Install Calico** - Prompts for cluster name and installs Calico. The kind config must disable the default CNI and use the Calico pod subnet
4. **Install kube-vip** - Prompts for cluster name, auto-detects LoadBalancer range from Docker `kind` network (or asks), deploys kube-vip cloud controller, ConfigMap, RBAC, and DaemonSet on `eth0`
5. **Install etcdctl/etcdutl** - Copies `etcdctl` and `etcdutl` into the control-plane nodes
6. **Delete cluster** - Delete an existing cluster (with confirmation/retry)
7. **Cleanup** - Remove EasyKind scripts from `/usr/local/bin` and assets from `/usr/local/share/easykind`
8. **Exit**

## Configuration

### Cluster config
`create_cluster` looks for `config-cluster.yaml` in this order:
1. `KIND_CLUSTER_CONFIG` environment variable
2. `scripts/../assets/config-cluster.yaml` (dev checkout)
3. `/usr/local/share/easykind/assets/config-cluster.yaml` (installed)

The included `assets/config-cluster.yaml` creates 3 control-plane nodes and 1 worker. It disables the default CNI and sets `podSubnet: "192.168.0.0/16"` so Calico can be installed after the cluster is created.

### Calico
- Version: pulled from GitHub latest release, or set `CALICO_VERSION` (for example `v3.33.0`) to override
- Pod CIDR: Calico uses its default `192.168.0.0/16`; the kind config must set the same `podSubnet`
- Requires the cluster to be created with `networking.disableDefaultCNI: true`

### kube-vip
- Version: pulled from GitHub latest release, or set `KUBE_VIP_VERSION` to override
- LoadBalancer range: inferred from `docker network inspect kind`. For `/16` uses `.100.10-.100.30`, for `/24` uses `.100-.130`. Otherwise prompts interactively
- Interface: hardcoded to `eth0`
- Context: uses `kind-<cluster_name>`

## Development

Scripts are modular and can be run directly or sourced:
- Shared helpers: `scripts/common` (`log_info/warn/error`, `request_user_input`, timestamps)
- Follow `script_template` for new scripts (source `common`, define a function, guard with `BASH_SOURCE[0] == "$0"` to run when executed directly)
- All scripts use `set -euo pipefail`

Run from repo root for dev:
```bash
./scripts/install_binaries
./scripts/create_cluster
./scripts/install_calico
./scripts/kube_vip
./scripts/delete_cluster
./scripts/cleanup
```

## Troubleshooting

- **gum not found**: Install gum or run `bootstrap.sh`. The menu exits if gum is missing.
- **Docker group not applied**: After installing Docker, log out and back in (or `newgrp docker`).
- **Cluster config missing**: Set `KIND_CLUSTER_CONFIG=/path/to/config.yaml` or copy a config to `assets/` before running.
- **Calico refuses to install**: The cluster still has kindnet. Recreate the cluster with `networking.disableDefaultCNI: true` and `podSubnet: "192.168.0.0/16"` before running `install_calico`.
- **kube-vip range wrong / network not found**: Ensure Docker is running and the `kind` network exists (`docker network inspect kind`). If not using default Kind subnet, you'll be prompted to enter a range manually.
- **Go PATH**: If `kind` isn't found after install, ensure `$(go env GOPATH)/bin` is in your PATH (bootstrap adds it to `~/.bashrc`).
- **Legacy conflict**: `bootstrap.sh` removes `/usr/local/bin/install` if it exists.

## License

[MIT](LICENSE)
