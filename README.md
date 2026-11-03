# EasyKind

A simple set of Bash scripts to create and operate a [Kind](https://kind.sigs.k8s.io/) (Kubernetes-in-Docker) cluster on Linux. EasyKind installs the host tools, creates the cluster, bootstraps Calico and kube-vip, and can install Envoy Gateway from the command line or connect Argo CD to a GitOps repository. Choose either EasyKind or Argo CD to manage a component.

## What it installs

- [Docker](https://docs.docker.com/) (via [get.docker.com](https://get.docker.com))
- [kind](https://kind.sigs.k8s.io/) `v0.33.0` (via `go install`)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/) (latest stable from dl.k8s.io, arch-aware)
- [Helm](https://helm.sh/) (via get-helm-3)
- [gum](https://github.com/charmbracelet/gum) (for the interactive CLI)
- Go (if missing) and inotify limits tuned for Kind
- [Calico](https://www.tigera.io/project-calico/) as a policy-capable CNI (required by the included cluster config)
- Optional: [kube-vip](https://kube-vip.io/) for LoadBalancer services
- Optional: [Envoy Gateway](https://gateway.envoyproxy.io/) for Gateway API, installed by EasyKind or declared in GitOps
- Optional: [Argo CD](https://argo-cd.readthedocs.io/) for GitOps continuous delivery

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
2. **Create cluster** - Prompts for cluster name and lets you use the default Kind config, provide your own Kind `Cluster` YAML, or choose control-plane and worker counts. Then prompts for the Kubernetes (`kindest/node`) version and optional `--retain` for failed nodes
3. **Install Calico** - Prompts for cluster name and Calico version (Enter uses the latest release), then installs Calico. The kind config must disable the default CNI and use the Calico pod subnet
4. **Install kube-vip** - Prompts for cluster name and kube-vip version, auto-detects the LoadBalancer range from the Docker `kind` network (or asks), and bootstraps kube-vip for service LoadBalancer addresses
5. **Install Argo CD** - Prompts for cluster name and Argo CD version (Enter uses the latest release), applies the upstream install manifest, and waits for Argo CD to become ready
6. **Configure GitOps** - Registers a Git repository in Argo CD and asks which repository path to manage. Press Enter to use the repository root
7. **Install etcdctl/etcdutl** - Prompts for cluster name and etcd version (Enter uses the latest release), then copies `etcdctl` and `etcdutl` into the control-plane nodes
8. **Upgrade cluster** - Prompts for cluster name and target Kubernetes version (Enter uses the latest patch of the next minor), then upgrades the control-plane and worker nodes in place
9. **Delete cluster** - Delete an existing cluster (with confirmation/retry)
10. **Cleanup** - Remove EasyKind scripts from `/usr/local/bin` and assets from `/usr/local/share/easykind`
11. **Exit**

## Configuration

### Cluster config
When `KIND_CLUSTER_CONFIG` is set, `create_cluster` uses that readable Kind `Cluster` YAML file directly. Otherwise, choose one of three options at the prompt:

1. **Default**: use `assets/config-cluster.yaml` from the checkout, or `/usr/local/share/easykind/assets/config-cluster.yaml` after installation.
2. **File**: provide a path to your own Kind `Cluster` YAML file.
3. **Node counts**: enter the number of control-plane nodes (minimum 1) and worker nodes (0 or more). EasyKind generates a temporary Kind config and removes it after cluster creation.

The included default config creates 3 control-plane nodes and 1 worker. The generated node-count config uses the same networking settings and port mappings. Both disable the default CNI and set `podSubnet: "192.168.0.0/16"` so Calico can be installed after the cluster is created. If you provide your own file and plan to install Calico, configure those networking settings in your YAML too.

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
- Direct install: run `main --install-envoy-gateway`. EasyKind prompts for the cluster name and version, installs the `gateway-helm` OCI chart, and creates GatewayClass `eg`. This command works without opening the interactive menu.
- GitOps install: add an Argo CD Application for the same chart and declare GatewayClass `eg` in the connected Git repository.
- Choose one manager for the `eg` release and GatewayClass. Do not let EasyKind and Argo CD manage the same resources at once.
- Add `Gateway`, `HTTPRoute` and related resources to Git when using GitOps. Install kube-vip first if a `Gateway` needs a `LoadBalancer` address.

After running `bootstrap.sh`, call `main --install-envoy-gateway` from any terminal. From a source checkout, run `./scripts/main --install-envoy-gateway`.

### Argo CD
- Version: prompted at install time. Press Enter to use the latest GitHub release, or type a version (for example `v3.5.6`). Set `ARGOCD_VERSION` to change the default shown in the prompt
- Namespace: `argocd`
- Installs the upstream `manifests/install.yaml` for the selected release with `kubectl apply --server-side`, which avoids the CRD annotation size limit, and waits for the Argo CD deployments and application controller
- The port-forward remains available for private access: `kubectl --context kind-<cluster_name> -n argocd port-forward svc/argocd-server 8080:443`, then open `https://localhost:8080`
- Get the initial admin password with `kubectl --context kind-<cluster_name> -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`
- Install after Calico; kube-vip and Envoy Gateway are not required

### GitOps
- Run after **Install Argo CD**. Registers the Git repository as an Argo CD repository Secret and creates one Argo `Application` for the path you choose
- Repository URL: required at the prompt; there is no default. For automation, set `GITOPS_REPO_URL`
- Repository path: prompted at setup; press Enter for the repository root (`.`), or set `GITOPS_REPO_PATH`. Paths are relative to the repository root
- Application name: derived from the repository name and path basename; destination namespace defaults to `default`
- Authentication: public repository, private HTTPS with username + token, or private SSH with a private key
- Private HTTPS (recommended for GitHub): create a fine-grained PAT with **Contents: Read-only** for that repo. Use your GitHub username (or `x-access-token`) and the PAT as the password
- Private HTTPS stores `username` and `password` in the Argo CD repository Secret; private SSH stores `sshPrivateKey`. GitHub/GitLab SSH host keys are already trusted by Argo CD; add self-hosted host keys to `argocd-ssh-known-hosts-cm`
- Default branch: `main`; override with `GITOPS_REPO_BRANCH`
- The Application uses automated sync with `prune: false` and `selfHeal: true`, so existing objects are adopted and updated but not deleted
- Argo CD manages the workloads and platform add-ons declared in the connected GitOps repository. Envoy Gateway can instead be installed by EasyKind; do not configure both for the same release
- EasyKind keeps cluster creation, Calico, kube-vip bootstrap, the initial Argo CD installation, node tools, Kubernetes upgrades and etcd backup/restore

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
./scripts/main --install-envoy-gateway
./scripts/install_argocd
./scripts/configure_gitops
./scripts/install_etcdctl
./scripts/upgrade_cluster
./scripts/delete_cluster
./scripts/cleanup
```

## Troubleshooting

- **gum not found**: Install gum or run `bootstrap.sh`. The menu exits if gum is missing.
- **Docker group not applied**: After installing Docker, log out and back in (or `newgrp docker`).
- **Cluster config missing**: Choose a readable YAML file with the create-cluster prompt, or set `KIND_CLUSTER_CONFIG=/path/to/config.yaml`. The default option needs the included `assets/config-cluster.yaml` (or the installed asset).
- **Calico refuses to install**: The cluster still has kindnet. Recreate the cluster with `networking.disableDefaultCNI: true` and `podSubnet: "192.168.0.0/16"` before running `install_calico`.
- **kube-vip range wrong / network not found**: Ensure Docker is running and the `kind` network exists (`docker network inspect kind`). If not using default Kind subnet, you'll be prompted to enter a range manually.
- **Envoy Gateway is not ready**: Check the `envoy-gateway` Argo CD Application and its events. If a `Gateway` has no address, verify kube-vip and its configured LoadBalancer range.
- **Argo CD install fails with `metadata.annotations: Too long`**: the upstream CRDs exceed the client-side apply annotation limit. The script uses `kubectl apply --server-side --force-conflicts`; re-run the installation to finish a partially applied install.
- **Argo CD UI is not reachable**: `argocd-server` is a ClusterIP Service. Use the printed `kubectl port-forward` command or expose it with your own Ingress/LoadBalancer.
- **Argo CD cannot clone the GitOps repo**: the repository must be public or have credentials; verify the URL and branch, then check `kubectl -n argocd get applications` and the Application events.
- **Upgrade preflight fails with `SystemVerification`**: Kind node containers cannot load the host kernel's `configs` module. The upgrade script passes `--ignore-preflight-errors=SystemVerification`; other preflight checks still run.
- **Upgrade has no default target**: The cluster is already on the newest stable minor, so there is no next minor to upgrade to yet. Enter an existing target version manually or use a cluster on an older minor.
- **Go PATH**: If `kind` isn't found after install, ensure `$(go env GOPATH)/bin` is in your PATH (bootstrap adds it to `~/.bashrc`).
- **Legacy conflict**: `bootstrap.sh` removes `/usr/local/bin/install` if it exists.

## License

[MIT](LICENSE)
