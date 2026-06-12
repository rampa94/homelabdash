#!/usr/bin/env bash
# ============================================================
#  HomeLab Dashboard — Proxmox CT Creator / Updater
#  Run on Proxmox host:
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
VLAN_TAG=""
TIMEZONE=""

msg_info()  { echo -e "${BL}  [INFO]${CL} ${1}"; }
msg_ok()    { echo -e "${GN}  [OK]${CL} ${1}"; }
msg_error() { echo -e "${RD}  [ERROR]${CL} ${1}"; exit 1; }

header() {
  clear
  echo -e "${BOLD}"
  cat << "EOF"
  ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗ ██████╗  █████╗ ███████╗██╗  ██╗
  ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝██║  ██║
  ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝██║  ██║███████║███████╗███████║
  ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗██║  ██║██╔══██║╚════██║██╔══██║
  ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝██████╔╝██║  ██║███████║██║  ██║
  ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
EOF
  echo -e "${CL}"
  echo -e "  ${BOLD}HomeLab Dashboard LXC Installer / Updater${CL}"
  echo -e "  Self-hosted app bookmarks + server inventory"
  echo "  ──────────────────────────────────────────────────────"
  echo ""
}

check_proxmox() {
  if ! command -v pveversion &>/dev/null; then
    msg_error "This script must be run on a Proxmox VE host."
  fi
  if [ "$(id -u)" -ne 0 ]; then
    msg_error "Please run as root."
  fi
}

# ─── Detect existing CT ───────────────────────────────────────
find_existing_ct() {
  EXISTING_CTID=$(pct list | awk 'NR>1 {print $1, $3}' | grep "homelabdash" | awk '{print $1}' | head -1)
}

# ─── UPDATE mode ─────────────────────────────────────────────
do_update() {
  msg_info "Updating HomeLab Dashboard in CT ${EXISTING_CTID}..."

  # Ensure CT is running
  if [ "$(pct status "$EXISTING_CTID" | awk '{print $2}')" != "running" ]; then
    msg_info "Starting CT ${EXISTING_CTID}..."
    pct start "$EXISTING_CTID"
    sleep 3
  fi

  pct exec "$EXISTING_CTID" -- bash -c "
    apt-get install -y -qq wget curl
    wget -qO /tmp/install_ct.sh '${INSTALL_SCRIPT}'
    chmod +x /tmp/install_ct.sh
    MODE=update bash /tmp/install_ct.sh
  "
  msg_ok "Update complete"

  CT_IP=$(pct exec "$EXISTING_CTID" -- hostname -I | awk '{print $1}')
  echo ""
  echo "  ──────────────────────────────────────────"
  echo -e "  ${GN}${BOLD}HomeLab Dashboard updated!${CL}"
  echo "  ──────────────────────────────────────────"
  echo -e "  ${BOLD}URL:${CL}  http://${CT_IP}:${APP_PORT}"
  echo -e "  ${BOLD}CT:${CL}   ${EXISTING_CTID} (homelabdash)"
  echo ""
  echo -e "  To update again in the future, just re-run:"
  echo -e "  ${BL}bash -c \"\$(wget -qLO - https://raw.githubusercontent.com/rampa94/homelabdash/main/homelabdash.sh)\"${CL}"
  echo "  ──────────────────────────────────────────"
  echo ""
}

# ─── INSTALL mode ────────────────────────────────────────────
select_storage() {
  STORAGE_LIST=$(pvesm status -content rootdir | awk 'NR>1 {print $1}')
  COUNT=$(echo "$STORAGE_LIST" | wc -l)
  if [ "$COUNT" -gt 1 ]; then
    STORAGE=$(whiptail --title "Storage" \
      --menu "Select storage for the CT:" 15 50 5 \
      $(echo "$STORAGE_LIST" | awk '{print $1, $1}') \
      3>&1 1>&2 2>&3) || msg_error "Cancelled."
  else
    STORAGE=$(echo "$STORAGE_LIST" | head -1)
  fi
  msg_ok "Storage: ${STORAGE}"
}

select_mode() {
  MODE=$(whiptail --title "HomeLab Dashboard" \
    --menu "\nSelect installation mode:" 15 55 2 \
    "1" "Default      (recommended)" \
    "2" "Advanced     (customize parameters)" \
    3>&1 1>&2 2>&3) || msg_error "Cancelled."
}

advanced_settings() {
  APP_PORT=$(whiptail --title "App Port" \
    --inputbox "Port for HomeLab Dashboard:" 10 50 "$APP_PORT" \
    3>&1 1>&2 2>&3) || msg_error "Cancelled."

  RAM_SIZE=$(whiptail --title "RAM" \
    --inputbox "RAM assigned to CT (MB):" 10 50 "$RAM_SIZE" \
    3>&1 1>&2 2>&3) || msg_error "Cancelled."

  CORE_COUNT=$(whiptail --title "CPU" \
    --inputbox "Number of CPU cores:" 10 50 "$CORE_COUNT" \
    3>&1 1>&2 2>&3) || msg_error "Cancelled."

  DISK_SIZE=$(whiptail --title "Disk" \
    --inputbox "Disk size (GB):" 10 50 "$DISK_SIZE" \
    3>&1 1>&2 2>&3) || msg_error "Cancelled."

  TIMEZONE=$(whiptail --title "Timezone" \
    --inputbox "Timezone (leave empty to use Proxmox host timezone):" 10 60 "" \
    3>&1 1>&2 2>&3) || msg_error "Cancelled."

  if whiptail --title "VLAN" --yesno "Assign a VLAN to the CT?" 10 50; then
    VLAN_TAG=$(whiptail --title "VLAN Tag" \
      --inputbox "Enter VLAN tag (e.g. 10, 20, 100):" 10 50 "" \
      3>&1 1>&2 2>&3) || msg_error "Cancelled."
  fi
}

confirm() {
  CTID=$(pvesh get /cluster/nextid)
  VLAN_INFO=""
  [ -n "$VLAN_TAG" ] && VLAN_INFO="\n  VLAN:     ${VLAN_TAG}"
  TZ_INFO="${TIMEZONE:-$(timedatectl show --property=Timezone --value 2>/dev/null || echo 'Europe/Rome')}"
  whiptail --title "Installation Summary" --yesno \
"The following CT will be created:

  CT ID:    ${CTID}
  OS:       Debian ${OS_VERSION}
  RAM:      ${RAM_SIZE} MB
  CPU:      ${CORE_COUNT} core(s)
  Disk:     ${DISK_SIZE} GB
  Storage:  ${STORAGE}
  Port:     ${APP_PORT}
  Timezone: ${TZ_INFO}${VLAN_INFO}

Proceed?" 22 52 || msg_error "Cancelled."
}

get_template() {
  msg_info "Checking Debian ${OS_VERSION} template..."
  TEMPLATE=$(pveam available --section system | grep "debian-${OS_VERSION}" | sort -V | tail -1 | awk '{print $2}')
  [ -z "$TEMPLATE" ] && msg_error "Debian ${OS_VERSION} template not found."

  TEMPLATE_STORAGE=$(pvesm status -content vztmpl | awk 'NR>1 {print $1}' | head -1)
  if ! pveam list "$TEMPLATE_STORAGE" | grep -q "$TEMPLATE"; then
    msg_info "Downloading template ${TEMPLATE}..."
    pveam download "$TEMPLATE_STORAGE" "$TEMPLATE" >/dev/null 2>&1
  fi
  TEMPLATE_PATH="${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}"
  msg_ok "Template ready"
}

create_ct() {
  msg_info "Creating CT ${CTID}..."
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
  msg_ok "CT ${CTID} created and started"
  sleep 5
}

install_app() {
  msg_info "Installing HomeLab Dashboard in CT..."

  if [ -z "$TIMEZONE" ]; then
    TIMEZONE=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "Europe/Rome")
  fi

  pct exec "$CTID" -- bash -c "
    apt-get update -qq && apt-get install -y -qq wget
    wget -qO /tmp/install_ct.sh '${INSTALL_SCRIPT}'
    chmod +x /tmp/install_ct.sh
    APP_PORT=${APP_PORT} TIMEZONE='${TIMEZONE}' MODE=install bash /tmp/install_ct.sh
  "
  msg_ok "Installation complete"
}

# ─── Main ─────────────────────────────────────────────────────
header
check_proxmox
find_existing_ct

if [ -n "$EXISTING_CTID" ]; then
  # CT already exists — ask to update
  whiptail --title "Existing Installation Found" --yesno \
"HomeLab Dashboard CT found (ID: ${EXISTING_CTID}).

Do you want to update it to the latest version?
(Your data will be preserved)" 12 55 || msg_error "Cancelled."
  do_update
else
  # Fresh install
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
  echo -e "  ${GN}${BOLD}All done!${CL}"
  echo "  ──────────────────────────────────────────"
  echo -e "  ${BOLD}URL:${CL}  http://${CT_IP}:${APP_PORT}"
  echo -e "  ${BOLD}CT:${CL}   ${CTID} (homelabdash)"
  echo ""
  echo -e "  To update HomeLab Dashboard in the future,"
  echo -e "  just re-run this script:"
  echo -e "  ${BL}bash -c \"\$(wget -qLO - https://raw.githubusercontent.com/rampa94/homelabdash/main/homelabdash.sh)\"${CL}"
  echo "  ──────────────────────────────────────────"
  echo ""
fi
