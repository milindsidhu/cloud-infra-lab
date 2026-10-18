#!/usr/bin/env bash
set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*" >&2; }
step() { echo -e "\n${BLUE}══ $* ══${NC}"; }

# ─── Root check ───────────────────────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
  err "Do not run as root. Run as a normal user with sudo access."
  exit 1
fi

SUDO="sudo"
command -v sudo &>/dev/null || { err "sudo not found"; exit 1; }

# ─── OS detection ─────────────────────────────────────────────────────────────
OS=""
PKG=""
if [[ -f /etc/os-release ]]; then
  # shellcheck source=/dev/null
  source /etc/os-release
  case "$ID" in
    ubuntu|debian|linuxmint) OS="debian"; PKG="apt-get" ;;
    fedora|rhel|centos|rocky|almalinux) OS="rhel"; PKG="dnf" ;;
    arch|manjaro) OS="arch"; PKG="pacman" ;;
    *) warn "Unrecognised distro '$ID' — proceeding with best effort." ;;
  esac
elif [[ "$(uname)" == "Darwin" ]]; then
  OS="macos"
fi

[[ -z "$OS" ]] && { err "Cannot determine OS. Aborting."; exit 1; }
log "Detected OS: $OS"

# ─── Helpers ──────────────────────────────────────────────────────────────────
installed() { command -v "$1" &>/dev/null; }

apt_install() {
  $SUDO apt-get install -y --no-install-recommends "$@"
}

# ─── 1. System update & base deps ─────────────────────────────────────────────
step "System update & base dependencies"
case "$OS" in
  debian)
    $SUDO apt-get update -y
    $SUDO apt-get upgrade -y
    apt_install curl wget gnupg lsb-release ca-certificates \
                apt-transport-https software-properties-common unzip git
    ;;
  rhel)
    $SUDO dnf upgrade -y
    $SUDO dnf install -y curl wget gnupg2 ca-certificates unzip git
    ;;
  arch)
    $SUDO pacman -Syu --noconfirm
    $SUDO pacman -S --noconfirm --needed curl wget gnupg unzip git
    ;;
  macos)
    # Xcode CLI tools — needed for brew
    xcode-select --install 2>/dev/null || true
    ;;
esac
log "System updated."

# ─── 2. Homebrew (Linux & macOS) ──────────────────────────────────────────────
step "Homebrew"
if installed brew; then
  log "brew already installed — updating."
  brew update
else
  log "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for the rest of this script
  if [[ "$OS" != "macos" ]]; then
    # Linux default location
    BREW_PREFIX="/home/linuxbrew/.linuxbrew"
    [[ -d "$HOME/.linuxbrew" ]] && BREW_PREFIX="$HOME/.linuxbrew"
    eval "$("$BREW_PREFIX/bin/brew" shellenv)"

    # Persist for future shells
    SHELL_RC="$HOME/.bashrc"
    [[ -n "${ZSH_VERSION:-}" ]] && SHELL_RC="$HOME/.zshrc"
    if ! grep -q "brew shellenv" "$SHELL_RC" 2>/dev/null; then
      {
        echo ''
        echo '# Homebrew'
        echo "eval \"\$(${BREW_PREFIX}/bin/brew shellenv)\""
      } >> "$SHELL_RC"
      log "Homebrew env added to $SHELL_RC"
    fi
  else
    # macOS Apple Silicon
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  fi
  log "Homebrew installed."
fi

# ─── 3. Docker ────────────────────────────────────────────────────────────────
step "Docker"
if installed docker; then
  warn "Docker already installed ($(docker --version))."
else
  case "$OS" in
    debian)
      # Official Docker repo
      $SUDO install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/"${ID}"/gpg \
        | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${ID} $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
      $SUDO apt-get update -y
      apt_install docker-ce docker-ce-cli containerd.io \
                  docker-buildx-plugin docker-compose-plugin
      ;;
    rhel)
      $SUDO dnf config-manager --add-repo \
        https://download.docker.com/linux/centos/docker-ce.repo
      $SUDO dnf install -y docker-ce docker-ce-cli containerd.io \
                           docker-buildx-plugin docker-compose-plugin
      ;;
    arch)
      $SUDO pacman -S --noconfirm --needed docker docker-compose
      ;;
    macos)
      warn "On macOS, install Docker Desktop from https://www.docker.com/products/docker-desktop"
      warn "Skipping automated Docker install on macOS."
      ;;
  esac

  if [[ "$OS" != "macos" ]]; then
    $SUDO systemctl enable --now docker
    $SUDO usermod -aG docker "$USER"
    log "Docker installed. Log out and back in for group membership to take effect."
  fi
fi

# ─── 4. kubectl ───────────────────────────────────────────────────────────────
step "kubectl"
if installed kubectl; then
  warn "kubectl already installed ($(kubectl version --client --short 2>/dev/null || kubectl version --client))."
else
  KUBE_VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
  ARCH=$(uname -m)
  case "$ARCH" in x86_64) ARCH="amd64" ;; aarch64|arm64) ARCH="arm64" ;; esac
  KUBE_URL="https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${ARCH}/kubectl"
  [[ "$OS" == "macos" ]] && KUBE_URL="https://dl.k8s.io/release/${KUBE_VERSION}/bin/darwin/${ARCH}/kubectl"

  curl -fsSL "$KUBE_URL" -o /tmp/kubectl
  # Verify checksum
  curl -fsSL "${KUBE_URL}.sha256" -o /tmp/kubectl.sha256
  echo "$(cat /tmp/kubectl.sha256)  /tmp/kubectl" | sha256sum --check --status
  $SUDO install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
  rm -f /tmp/kubectl /tmp/kubectl.sha256
  log "kubectl ${KUBE_VERSION} installed."
fi

# ─── 5. Helm ──────────────────────────────────────────────────────────────────
step "Helm"
if installed helm; then
  warn "Helm already installed ($(helm version --short))."
else
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    | bash
  log "Helm installed ($(helm version --short))."
fi

# ─── 6. Terraform ─────────────────────────────────────────────────────────────
step "Terraform"
if installed terraform; then
  warn "Terraform already installed ($(terraform version | head -1))."
else
  case "$OS" in
    debian)
      wget -O- https://apt.releases.hashicorp.com/gpg \
        | $SUDO gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
        | $SUDO tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
      $SUDO apt-get update -y
      apt_install terraform
      ;;
    rhel)
      $SUDO dnf install -y dnf-plugins-core
      $SUDO dnf config-manager --add-repo \
        https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
      $SUDO dnf install -y terraform
      ;;
    arch)
      # AUR helper check; fall back to direct binary
      if installed yay; then
        yay -S --noconfirm terraform
      else
        TF_VERSION=$(curl -fsSL https://api.releases.hashicorp.com/v1/releases/terraform/latest \
          | grep -oP '"version":"\K[^"]+' | head -1)
        ARCH=$(uname -m); [[ "$ARCH" == "x86_64" ]] && ARCH="amd64"
        curl -fsSLo /tmp/terraform.zip \
          "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_${ARCH}.zip"
        unzip -o /tmp/terraform.zip -d /tmp
        $SUDO install -m 0755 /tmp/terraform /usr/local/bin/terraform
        rm -f /tmp/terraform.zip /tmp/terraform
      fi
      ;;
    macos)
      brew tap hashicorp/tap
      brew install hashicorp/tap/terraform
      ;;
  esac
  log "Terraform installed ($(terraform version | head -1))."
fi

# ─── 7. SSH key generation ────────────────────────────────────────────────────
step "SSH key"
SSH_DIR="$HOME/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

KEY_PATH="$SSH_DIR/id_ed25519"
if [[ -f "$KEY_PATH" ]]; then
  warn "SSH key already exists at $KEY_PATH — skipping generation."
else
  read -rp "Enter email for SSH key comment [$(whoami)@$(hostname)]: " SSH_EMAIL
  SSH_EMAIL="${SSH_EMAIL:-$(whoami)@$(hostname)}"
  ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$KEY_PATH" -N ""
  log "SSH key generated: $KEY_PATH"
  log "Public key:"
  cat "${KEY_PATH}.pub"
fi

# Ensure ssh-agent has the key
if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
  eval "$(ssh-agent -s)" > /dev/null
fi
ssh-add "$KEY_PATH" 2>/dev/null || true

# ─── 8. Verify installations ──────────────────────────────────────────────────
step "Verification"
tools=(docker kubectl helm terraform brew)
all_ok=true
for t in "${tools[@]}"; do
  if installed "$t"; then
    log "$t: OK"
  else
    warn "$t: NOT FOUND (may need a new shell or logout/login)"
    all_ok=false
  fi
done

echo ""
if $all_ok; then
  log "All tools installed successfully."
else
  warn "Some tools were not found in PATH. Open a new terminal and re-run 'which <tool>'."
fi

echo ""
log "SSH public key (add to GitHub/GitLab/etc.):"
cat "${SSH_DIR}/id_ed25519.pub"

echo ""
warn "If Docker was just installed, log out and back in (or run 'newgrp docker') to use it without sudo."
