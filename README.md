# EasyKind

A simple set of Bash scripts to spin up a local [Kind](https://kind.sigs.k8s.io/) (Kubernetes-in-Docker) cluster on Linux, install common CLI tools, install [Calico](https://www.tigera.io/project-calico/) as the CNI, optionally set up [kube-vip](https://kube-vip.io/) as a LoadBalancer, and optionally install [Envoy Gateway](https://gateway.envoyproxy.io/) for Gateway API routes.

## What it installs

- [Docker](https://docs.docker.com/) (via [get.docker.com](https://get.docker.com))
- [kind](https://kind.sigs.k8s.io/) `v0.33.0` (via `go install`)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/) (latest stable from dl.k8s.io, arch-aware)
- [Helm](https://helm.sh/) (via get-helm-3)
- [gum](https://github.com/charmbracelet/gum) (for the interactive CLI)
- Go (if missing) and inotify limits tuned for Kind
- [Calico](https://www.tigera.io/project-calico/) as a policy-capable CNI (required by the included cluster config)
- Optional: [kube-vip](https://kube-vip.io/) for LoadBalancer services
- Optional: [Envoy Gateway](https://gateway.envoyproxy.io/) for Gateway API (`GatewayClass`, `Gateway`, `HTTPRoute`)

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
2. **Create cluster** - Prompts for cluster name and Kubernetes (`kindest/node`) version, uses a Kind config, optional `--retain` for failed nodes
3. **Install Calico** - Prompts for cluster name and Calico version (Enter uses the latest release), then installs Calico. The kind config must disable the default CNI and use the Calico pod subnet
4. **Install kube-vip** - Prompts for cluster name and kube-vip version (Enter uses the latest release), auto-detects LoadBalancer range from Docker `kind` network (or asks), deploys kube-vip cloud controller, ConfigMap, RBAC, and DaemonSet on `eth0`
5. **Install Envoy Gateway** - Prompts for cluster name and Envoy Gateway version (Enter uses the latest release), installs it via Helm, and creates the `eg` GatewayClass. A `Gateway` gets a kube-vip LoadBalancer address when created
6. **Install etcdctl/etcdutl** - Prompts for cluster name and etcd version (Enter uses the latest release), then copies `etcdctl` and `etcdutl` into the control-plane nodes
7. **Upgrade cluster** - Prompts for cluster name and target Kubernetes version (Enter uses the latest patch of the next minor), then upgrades the control-plane and worker nodes in place
8. **Delete cluster** - Delete an existing cluster (with confirmation/retry)
9. **Cleanup** - Remove EasyKind scripts from `/usr/local/bin` and assets from `/usr/local/share/easykind`
10. **Exit**

## Configuration

### Cluster config
`create_cluster` looks for `config-cluster.yaml` in this order:
1. `KIND_CLUSTER_CONFIG` environment variable
2. `scripts/../assets/config-cluster.yaml` (dev checkout)
3. `/usr/local/share/easykind/assets/config-cluster.yaml` (installed)

The included `assets/config-cluster.yaml` creates 3 control-plane nodes and 1 worker. It disables the default CNI and sets `podSubnet: "192.168.0.0/16"` so Calico can be installed after the cluster is created.

The Kubernetes version is prompted at creation time and passed as `--image kindest/node:<version>`. Press Enter to use the default (`v1.37.0`, the kind `v0.33.0` default) or set `KIND_KUBERNETES_VERSION` to override the default.

### Calico
- Version: prompted at install time. Press Enter to use the latest GitHub release, or type a version (for example `v3.33.0`). Set `CALICO_VERSION` to change the default shown in the prompt
- Pod CIDR: Calico uses its default `192.168.0.0/16`; the kind config must set the same `podSubnet`
- Requires the cluster to be created with `networking.disableDefaultCNI: true`

### kube-vip
- Version: prompted at install time. Press Enter to use the latest GitHub release, or type a version. Set `KUBE_VIP_VERSION` to change the default shown in the prompt
- LoadBalancer range: inferred from `docker network inspect kind`. For `/16` uses `.100.10-.100.30`, for `/24` uses `.100-.130`. Otherwise prompts interactively
- Interface: hardcoded to `eth0`
- Context: uses `kind-<cluster_name>`

### Envoy Gateway
- Version: prompted at install time. Press Enter to use the latest GitHub release, or type a version (for example `v1.9.3`). Set `ENVOY_GATEWAY_VERSION` to change the default shown in the prompt
- Helm release: `eg` in namespace `envoy-gateway-system`
- Creates `GatewayClass` `eg`; create `Gateway` and `HTTPRoute` resources to expose workloads
- Install after kube-vip if the `Gateway` should receive a LoadBalancer address

### Upgrade
- Target: prompted at upgrade time. Press Enter to use the latest patch of the next Kubernetes minor (from `dl.k8s.io/release/stable-1.<next>.txt`), or type a version. Set `KIND_KUBERNETES_UPGRADE_VERSION` to change the default shown in the prompt
- Upgrades one minor at a time; same-minor patch upgrades are allowed, downgrades and skipped minors are rejected
- Copies the target `kubeadm`, `kubelet` and `kubectl` binaries into the kind nodes, verifies their SHA-256 checksums, then upgrades the first control-plane node, remaining control-plane nodes, and workers in order
- Passes `--ignore-preflight-errors=SystemVerification` because kind node containers cannot load the host kernel's `configs` module
- With a single worker, the worker is not drained (both replicas of a workload would have nowhere to go); kubelet is restarted so containers keep running. With multiple workers, workers are drained and uncordoned one at a time

## Development

Scripts are modular and can be run directly or sourced:
- Shared helpers: `scripts/common` (`log_info/warn/error`, `request_user_input`, `request_version`, timestamps)
- Follow `script_template` for new scripts (source `common`, define a function, guard with `BASH_SOURCE[0] == "$0"` to run when executed directly)
- All scripts use `set -euo pipefail`

Run from repo root for dev:
```bash
./scripts/install_binaries
./scripts/create_cluster
./scripts/install_calico
./scripts/kube_vip
./scripts/install_envoy_gateway
./scripts/install_etcdctl
./scripts/upgrade_cluster
./scripts/delete_cluster
./scripts/cleanup
```

## Troubleshooting

- **gum not found**: Install gum or run `bootstrap.sh`. The menu exits if gum is missing.
- **Docker group not applied**: After installing Docker, log out and back in (or `newgrp docker`).
- **Cluster config missing**: Set `KIND_CLUSTER_CONFIG=/path/to/config.yaml` or copy a config to `assets/` before running.
- **Calico refuses to install**: The cluster still has kindnet. Recreate the cluster with `networking.disableDefaultCNI: true` and `podSubnet: "192.168.0.0/16"` before running `install_calico`.
- **kube-vip range wrong / network not found**: Ensure Docker is running and the `kind` network exists (`docker network inspect kind`). If not using default Kind subnet, you'll be prompted to enter a range manually.
- **Envoy Gateway Gateway has no address**: Install kube-vip first, or check that the `Gateway` service received a LoadBalancer IP.
- **Upgrade preflight fails with `SystemVerification`**: Kind node containers cannot load the host kernel's `configs` module. The upgrade script passes `--ignore-preflight-errors=SystemVerification`; other preflight checks still run.
- **Upgrade has no default target**: The cluster is already on the newest stable minor, so there is no next minor to upgrade to yet. Enter an existing target version manually or use a cluster on an older minor.
- **Go PATH**: If `kind` isn't found after install, ensure `$(go env GOPATH)/bin` is in your PATH (bootstrap adds it to `~/.bashrc`).
- **Legacy conflict**: `bootstrap.sh` removes `/usr/local/bin/install` if it exists.

## License

[MIT](LICENSE)
