#!/bin/bash
# ============================================================
#  HomeLab Dashboard — Script installazione CT
#  Scarica l'app dall'ultima GitHub Release di rampa94/homelabdash
# ============================================================

set -e

APP_PORT="${APP_PORT:-3010}"
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

# ─── 1. Sistema ───────────────────────────────────────────────
msg_info "Aggiornamento sistema..."
apt-get update -qq && apt-get upgrade -y -qq
apt-get install -y -qq \
  curl wget unzip ca-certificates gnupg lsb-release \
  apt-transport-https openssl
msg_ok "Sistema aggiornato"

# ─── 2. Docker ───────────────────────────────────────────────
if command -v docker &>/dev/null; then
  msg_warn "Docker già installato, salto"
else
  msg_info "Installazione Docker..."
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
  msg_ok "Docker installato"
fi

# ─── 3. Download ultima release da GitHub ────────────────────
msg_info "Download ultima release da GitHub..."
TMP_ZIP=$(mktemp /tmp/homelabdash-XXXXXX.zip)
wget -q --show-progress -O "$TMP_ZIP" "$RELEASE_URL" \
  || msg_error "Download fallito. Verifica la connessione internet."
msg_ok "Download completato"

# ─── 4. Installazione ────────────────────────────────────────
msg_info "Installazione in ${INSTALL_DIR}..."
if [ -d "$INSTALL_DIR" ]; then
  BACKUP="${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
  msg_warn "Directory esistente, backup in ${BACKUP}"
  mv "$INSTALL_DIR" "$BACKUP"
fi

mkdir -p "$INSTALL_DIR"
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
msg_ok "File installati"

# ─── 5. Configurazione ───────────────────────────────────────
msg_info "Configurazione porta ${APP_PORT} e timezone..."
sed -i "s|\"[0-9]*:3000\"|\"${APP_PORT}:3000\"|g" \
  "${INSTALL_DIR}/docker-compose.yml"

TIMEZONE=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "Europe/Rome")
if ! grep -q "TZ=" "${INSTALL_DIR}/docker-compose.yml"; then
  sed -i "/DB_PATH/a\\      - TZ=${TIMEZONE}" \
    "${INSTALL_DIR}/docker-compose.yml"
fi
msg_ok "Configurazione completata"

# ─── 6. Avvio ────────────────────────────────────────────────
msg_info "Build e avvio container..."
cd "$INSTALL_DIR"
docker compose up -d --build
msg_ok "Container avviato"

# ─── 7. Healthcheck ──────────────────────────────────────────
msg_info "Verifica avvio applicazione..."
sleep 8
ATTEMPTS=0
until curl -sf "http://localhost:${APP_PORT}/" >/dev/null 2>&1; do
  ATTEMPTS=$((ATTEMPTS+1))
  [ $ATTEMPTS -ge 10 ] && { msg_warn "Timeout, l'app potrebbe impiegare qualche secondo in più"; break; }
  sleep 3
done
curl -sf "http://localhost:${APP_PORT}/" >/dev/null 2>&1 && msg_ok "App raggiungibile"

# ─── Fine ─────────────────────────────────────────────────────
IP=$(hostname -I | awk '{print $1}')
echo ""
echo "  ──────────────────────────────────────────"
echo -e "  ${GN}${BOLD}HomeLab Dashboard installato!${CL}"
echo "  ──────────────────────────────────────────"
echo -e "  URL:   ${BOLD}http://${IP}:${APP_PORT}${CL}"
echo -e "  Dir:   ${BOLD}${INSTALL_DIR}${CL}"
echo ""
echo "  Comandi utili:"
echo "    cd ${INSTALL_DIR} && docker compose logs -f"
echo "    cd ${INSTALL_DIR} && docker compose restart"
echo "    cd ${INSTALL_DIR} && docker compose down"
echo "  ──────────────────────────────────────────"
