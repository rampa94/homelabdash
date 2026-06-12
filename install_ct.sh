#!/bin/bash
# ============================================================
#  HomeLab Dashboard — CT Installation / Update Script
#  Runs automatically inside the LXC container
# ============================================================

set -e

APP_PORT="${APP_PORT:-3010}"
TIMEZONE="${TIMEZONE:-}"
MODE="${MODE:-install}"
INSTALL_DIR="/opt/homelabdash"
GITHUB_REPO="rampa94/homelabdash"
RELEASE_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/homelabdash.zip"

GN='\033[1;92m'
BL='\033[36m'
YW='\033[33m'
RD='\033[01;31m'
CL='\033[m'
BOLD='\033[1m'

msg_info()  { echo -e "${BL}  [INFO]${CL} $1"; }
msg_ok()    { echo -e "${GN}  [OK]${CL} $1"; }
msg_warn()  { echo -e "${YW}  [WARN]${CL} $1"; }
msg_error() { echo -e "${RD}  [ERROR]${CL} $1"; exit 1; }

# ─── 1. System update ─────────────────────────────────────────
msg_info "Updating system..."
apt-get update -qq && apt-get upgrade -y -qq
apt-get install -y -qq \
  curl wget unzip ca-certificates gnupg lsb-release \
  apt-transport-https openssl
msg_ok "System updated"

# ─── 2. Docker ───────────────────────────────────────────────
if command -v docker &>/dev/null; then
  msg_warn "Docker already installed, skipping"
else
  msg_info "Installing Docker..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable docker --now
  msg_ok "Docker installed"
fi

# ─── 3. Download latest release from GitHub ──────────────────
msg_info "Downloading latest release from GitHub..."
TMP_ZIP=$(mktemp /tmp/homelabdash-XXXXXX.zip)
wget -q -O "$TMP_ZIP" "$RELEASE_URL" \
  || msg_error "Download failed. Check internet connectivity."
msg_ok "Download complete"

# ─── 4. Install / Update files ───────────────────────────────
if [ "$MODE" = "update" ] && [ -d "$INSTALL_DIR" ]; then
  msg_info "Updating files (data volumes are preserved)..."
  # Stop container before update
  cd "$INSTALL_DIR" && docker compose down >/dev/null 2>&1 || true
  # Backup current install
  BACKUP="${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
  cp -r "$INSTALL_DIR" "$BACKUP"
  msg_ok "Backup saved to ${BACKUP}"
else
  msg_info "Installing to ${INSTALL_DIR}..."
  if [ -d "$INSTALL_DIR" ]; then
    BACKUP="${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    msg_warn "Existing directory found, backing up to ${BACKUP}"
    mv "$INSTALL_DIR" "$BACKUP"
  fi
  mkdir -p "$INSTALL_DIR"
fi

TMP_EXTRACT=$(mktemp -d /tmp/homelabdash_XXXXXX)
unzip -q "$TMP_ZIP" -d "$TMP_EXTRACT"

ITEMS=$(ls "$TMP_EXTRACT" | wc -l)
if [ "$ITEMS" -eq 1 ]; then
  SUBDIR=$(ls "$TMP_EXTRACT")
  cp -r "$TMP_EXTRACT/$SUBDIR/." "$INSTALL_DIR/"
else
  cp -r "$TMP_EXTRACT/." "$INSTALL_DIR/"
fi
rm -rf "$TMP_EXTRACT" "$TMP_ZIP"
msg_ok "Files installed"

# ─── 5. Configure port and timezone ──────────────────────────
msg_info "Configuring port and timezone..."
sed -i "s|\"[0-9]*:3000\"|\"${APP_PORT}:3000\"|g" \
  "${INSTALL_DIR}/docker-compose.yml"

if [ -z "$TIMEZONE" ]; then
  TIMEZONE=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "Europe/Rome")
fi

if ! grep -q "TZ=" "${INSTALL_DIR}/docker-compose.yml"; then
  sed -i "/DB_PATH/a\\      - TZ=${TIMEZONE}" \
    "${INSTALL_DIR}/docker-compose.yml"
fi
msg_ok "Configuration done (TZ: ${TIMEZONE})"

# ─── 6. Build and start ──────────────────────────────────────
msg_info "Building and starting container..."
cd "$INSTALL_DIR"
docker compose up -d --build
msg_ok "Container started"

# ─── 7. Healthcheck ──────────────────────────────────────────
msg_info "Waiting for application to start..."
sleep 8
ATTEMPTS=0
until curl -sf "http://localhost:${APP_PORT}/" >/dev/null 2>&1; do
  ATTEMPTS=$((ATTEMPTS+1))
  [ $ATTEMPTS -ge 10 ] && { msg_warn "Timeout reached, app may need a few more seconds"; break; }
  sleep 3
done
curl -sf "http://localhost:${APP_PORT}/" >/dev/null 2>&1 && msg_ok "Application is reachable"

# ─── Done ─────────────────────────────────────────────────────
IP=$(hostname -I | awk '{print $1}')
echo ""
echo "  ──────────────────────────────────────────"
if [ "$MODE" = "update" ]; then
  echo -e "  ${GN}${BOLD}HomeLab Dashboard updated!${CL}"
else
  echo -e "  ${GN}${BOLD}HomeLab Dashboard installed!${CL}"
fi
echo "  ──────────────────────────────────────────"
echo -e "  URL:   ${BOLD}http://${IP}:${APP_PORT}${CL}"
echo -e "  Dir:   ${BOLD}${INSTALL_DIR}${CL}"
echo ""
echo "  Useful commands:"
echo "    cd ${INSTALL_DIR} && docker compose logs -f"
echo "    cd ${INSTALL_DIR} && docker compose restart"
echo "    cd ${INSTALL_DIR} && docker compose down"
echo "  ──────────────────────────────────────────"
