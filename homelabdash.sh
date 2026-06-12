#!/usr/bin/env bash
# ============================================================
#  HomeLab Dashboard — Proxmox CT Creator
#  Esegui sull'host Proxmox:
#  bash -c "$(wget -qLO - https://raw.githubusercontent.com/rampa94/homelabdash/main/homelabdash.sh)"
# ============================================================

set -e

YW='\033[33m'
BL='\033[36m'
RD='\033[01;31m'
GN='\033[1;92m'
CL='\033[m'
BOLD='\033[1m'

INSTALL_SCRIPT="https://raw.githubusercontent.com/rampa94/homelabdash/main/install_ct.sh"

CT_TYPE="1"
DISK_SIZE="4"
CORE_COUNT="1"
RAM_SIZE="512"
OS_VERSION="12"
APP_PORT="3010"

msg_info()  { echo -e "${BL}  [INFO]${CL} ${1}"; }
msg_ok()    { echo -e "${GN}  [OK]${CL} ${1}"; }
msg_error() { echo -e "${RD}  [ERROR]${CL} ${1}"; exit 1; }

header() {
  clear
  echo -e "${BOLD}"
  cat << "EOF"
  ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗
  ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗
  ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝
  ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗
  ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝
  ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝
EOF
  echo -e "${CL}"
  echo -e "  ${BOLD}HomeLab Dashboard LXC Installer${CL}"
  echo -e "  Bookmark app self-hosted + inventario server"
  echo "  ──────────────────────────────────────────────"
  echo ""
}

check_proxmox() {
  if ! command -v pveversion &>/dev/null; then
    msg_error "Questo script deve essere eseguito sull'host Proxmox VE."
  fi
  if [ "$(id -u)" -ne 0 ]; then
    msg_error "Esegui come root."
  fi
}

select_storage() {
  STORAGE_LIST=$(pvesm status -content rootdir | awk 'NR>1 {print $1}')
  COUNT=$(echo "$STORAGE_LIST" | wc -l)
  if [ "$COUNT" -gt 1 ]; then
    STORAGE=$(whiptail --title "Storage" \
      --menu "Seleziona lo storage per il CT:" 15 50 5 \
      $(echo "$STORAGE_LIST" | awk '{print $1, $1}') \
      3>&1 1>&2 2>&3) || msg_error "Annullato."
  else
    STORAGE=$(echo "$STORAGE_LIST" | head -1)
  fi
  msg_ok "Storage: ${STORAGE}"
}

select_mode() {
  MODE=$(whiptail --title "HomeLab Dashboard" \
    --menu "\nScegli la modalità di installazione:" 15 55 2 \
    "1" "Predefinita  (consigliata)" \
    "2" "Avanzata     (personalizza parametri)" \
    3>&1 1>&2 2>&3) || msg_error "Annullato."
}

advanced_settings() {
  APP_PORT=$(whiptail --title "Porta App" \
    --inputbox "Porta su cui sarà raggiungibile HomeLab Dashboard:" 10 50 "$APP_PORT" \
    3>&1 1>&2 2>&3) || msg_error "Annullato."

  RAM_SIZE=$(whiptail --title "RAM" \
    --inputbox "RAM assegnata al CT (MB):" 10 50 "$RAM_SIZE" \
    3>&1 1>&2 2>&3) || msg_error "Annullato."

  CORE_COUNT=$(whiptail --title "CPU" \
    --inputbox "Numero di core CPU:" 10 50 "$CORE_COUNT" \
    3>&1 1>&2 2>&3) || msg_error "Annullato."

  DISK_SIZE=$(whiptail --title "Disco" \
    --inputbox "Dimensione disco (GB):" 10 50 "$DISK_SIZE" \
    3>&1 1>&2 2>&3) || msg_error "Annullato."

  if whiptail --title "VLAN" --yesno "Vuoi assegnare una VLAN al CT?" 10 50; then
    VLAN_TAG=$(whiptail --title "VLAN Tag" \
      --inputbox "Inserisci il VLAN tag (es. 10, 20, 100):" 10 50 "" \
      3>&1 1>&2 2>&3) || msg_error "Annullato."
  fi
}

confirm() {
  CTID=$(pvesh get /cluster/nextid)
  VLAN_INFO=""
  [ -n "$VLAN_TAG" ] && VLAN_INFO="\n  VLAN:     ${VLAN_TAG}"
  whiptail --title "Riepilogo" --yesno \
"Verrà creato il seguente CT:

  CT ID:    ${CTID}
  OS:       Debian ${OS_VERSION}
  RAM:      ${RAM_SIZE} MB
  CPU:      ${CORE_COUNT} core
  Disco:    ${DISK_SIZE} GB
  Storage:  ${STORAGE}
  Porta:    ${APP_PORT}${VLAN_INFO}

Procedere?" 20 50 || msg_error "Annullato."
}

get_template() {
  msg_info "Verifica template Debian ${OS_VERSION}..."
  TEMPLATE=$(pveam available --section system | grep "debian-${OS_VERSION}" | sort -V | tail -1 | awk '{print $2}')
  [ -z "$TEMPLATE" ] && msg_error "Template Debian ${OS_VERSION} non trovato."

  TEMPLATE_STORAGE=$(pvesm status -content vztmpl | awk 'NR>1 {print $1}' | head -1)
  if ! pveam list "$TEMPLATE_STORAGE" | grep -q "$TEMPLATE"; then
    msg_info "Download template ${TEMPLATE}..."
    pveam download "$TEMPLATE_STORAGE" "$TEMPLATE" >/dev/null 2>&1
  fi
  TEMPLATE_PATH="${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}"
  msg_ok "Template pronto"
}

create_ct() {
  msg_info "Creazione CT ${CTID}..."
  ROOT_PASS=$(openssl rand -base64 12)

  NET_CONFIG="name=eth0,bridge=vmbr0,ip=dhcp"
  [ -n "$VLAN_TAG" ] && NET_CONFIG="${NET_CONFIG},tag=${VLAN_TAG}"

  pct create "$CTID" "$TEMPLATE_PATH" \
    --hostname homelabdash \
    --cores "$CORE_COUNT" \
    --memory "$RAM_SIZE" \
    --rootfs "${STORAGE}:${DISK_SIZE}" \
    --net0 "$NET_CONFIG" \
    --unprivileged "$CT_TYPE" \
    --features nesting=1 \
    --password "$ROOT_PASS" \
    --start 1 \
    --onboot 1 \
    >/dev/null 2>&1
  msg_ok "CT ${CTID} creato e avviato"
  sleep 5
}

install_app() {
  msg_info "Installazione HomeLab Dashboard nel CT..."
  pct exec "$CTID" -- bash -c "
    apt-get update -qq && apt-get install -y -qq wget
    wget -qO /tmp/install_ct.sh '${INSTALL_SCRIPT}'
    chmod +x /tmp/install_ct.sh
    APP_PORT=${APP_PORT} bash /tmp/install_ct.sh
  "
  msg_ok "Installazione completata"
}

# ─── Main ─────────────────────────────────────────────────────
header
check_proxmox
select_storage
select_mode
[ "$MODE" = "2" ] && advanced_settings
confirm
get_template
create_ct
install_app

sleep 3
CT_IP=$(pct exec "$CTID" -- hostname -I | awk '{print $1}')

echo ""
echo "  ──────────────────────────────────────────"
echo -e "  ${GN}${BOLD}Installazione completata!${CL}"
echo "  ──────────────────────────────────────────"
echo -e "  ${BOLD}URL:${CL}  http://${CT_IP}:${APP_PORT}"
echo -e "  ${BOLD}CT:${CL}   ${CTID} (homelabdash)"
echo "  ──────────────────────────────────────────"
echo ""
