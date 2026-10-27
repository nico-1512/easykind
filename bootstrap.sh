#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
ASSETS_DIR="$SCRIPT_DIR/assets"
BIN_DIR="/usr/local/bin"
SHARE_DIR="/usr/local/share/easykind"

echo "Installing Go"
if command -v go >/dev/null 2>&1; then
  echo "GO already installed"
else
  sudo apt-get -y install golang-go
fi


echo "Installing gum"
if command -v gum >/dev/null 2>&1; then
  echo "gum already installed"
else
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
  echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
  sudo apt update && sudo apt install gum
fi

echo "Increasing inotify limits"
sudo sysctl -w fs.inotify.max_user_instances=1024
sudo sysctl -w fs.inotify.max_user_watches=1048576
sudo tee /etc/sysctl.d/99-easykind.conf >/dev/null <<'EOF'
fs.inotify.max_user_instances=1024
fs.inotify.max_user_watches=1048576
EOF

echo "Adding Go binaries to PATH"
export PATH="$(go env GOPATH)/bin:${PATH}"
if ! grep -qF 'export PATH="$(go env GOPATH)/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
  echo 'export PATH="$(go env GOPATH)/bin:$PATH"' >> "$HOME/.bashrc"
  echo "Running source .bashrc"
  source ~/.bashrc
fi

if [[ -f "${BIN_DIR}/install" ]]; then
  echo "Removing legacy ${BIN_DIR}/install (conflicts with the system install command)"
  sudo rm -f "${BIN_DIR}/install"
fi

echo "Cloning scripts into ${BIN_DIR}"
for script in "$SCRIPTS_DIR"/*; do
  if [[ -f "$script" ]]; then
    name="$(basename "$script")"
    sudo cp "$script" "${BIN_DIR}/${name}"
    sudo chmod +x "${BIN_DIR}/${name}"
  fi
done

echo "Cloning assets into ${SHARE_DIR}"
sudo mkdir -p "${SHARE_DIR}/assets"
sudo cp "$ASSETS_DIR"/* "${SHARE_DIR}/assets/"

echo "Bootstrap completed! 🎉"
echo "You can find your scripts under ${BIN_DIR}"
echo "Start by running main from your terminal"
