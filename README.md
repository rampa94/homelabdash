# 🏠 HomeLab Dashboard

A clean, self-hosted dashboard for your homelab — manage your self-hosted app bookmarks with status monitoring, and keep an inventory of your servers, VMs and containers.

Built with **Node.js + Express**, **SQLite** and a vanilla JS frontend with a dark glassmorphism UI.

![HomeLab Dashboard](https://img.shields.io/badge/version-1.0.0-F59E0B?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![Docker](https://img.shields.io/badge/docker-ready-2496ED?style=flat-square&logo=docker)
![Proxmox](https://img.shields.io/badge/proxmox-LXC-E57000?style=flat-square)

---

## ✨ Features

- **App Bookmarks** — Add your self-hosted apps with icon (from [selfh.st](https://selfh.st/icons/)), name and URL
- **Status Monitoring** — Periodic online/offline checks via URL, IP or IP:Port with status saved to DB
- **Server Inventory** — Track servers, VMs and containers grouped by custom categories
- **Home Assistant Integration** — Display real-time sensor data (power, temperature, humidity) in the header
- **Edit Mode Toggle** — Show/hide CRUD controls with a single click for a cleaner interface
- **Settings Panel** — Customize title, accent color, check intervals, grid columns and more
- **Dark Mode** — Glassmorphism design with amber accent, fully responsive for tablet and mobile
- **Docker Ready** — Runs in a Docker container with persistent SQLite storage

---

## 🚀 Quick Install on Proxmox (LXC)

Run this command on your **Proxmox host** as root:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/rampa94/homelabdash/main/homelabdash.sh)"
```

The script will:
- Let you choose between **Default** and **Advanced** installation
- Create a Debian 12 LXC container (512MB RAM, 1 CPU core, 4GB disk)
- Install Docker inside the CT
- Download and deploy HomeLab Dashboard automatically
- Show you the URL when done

### Advanced options
In advanced mode you can customize:
- App port (default: `3010`)
- RAM, CPU cores, disk size
- Timezone
- VLAN tag

### Update
To update to the latest version, simply re-run the same script — it will detect the existing CT and update it while preserving your data:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/rampa94/homelabdash/main/homelabdash.sh)"
```

---

## 🐳 Manual Deploy with Docker

If you prefer to deploy manually (e.g. with Dockge or Portainer):

**1. Download the latest release**

Grab `homelabdash.zip` from the [Releases](https://github.com/rampa94/homelabdash/releases/latest) page and extract it.

**2. Edit `docker-compose.yml`** if needed (change port, timezone, etc.)

**3. Run**

```bash
cd homelabdash
docker compose up -d --build
```

Open `http://<YOUR_IP>:3010` in your browser.

---

## ⚙️ Configuration

All settings are available in the **Settings panel** (gear icon) inside the app:

| Setting | Default | Description |
|---------|---------|-------------|
| App Title | `HomeLab Dashboard` | Name shown in the header |
| Accent Color | `#F59E0B` | UI accent color |
| Check Interval | `5 min` | How often to check app status |
| Check Timeout | `5 sec` | Timeout before marking an app offline |
| Grid Columns | `Auto` | Number of columns in the app grid |
| HA URL | — | Home Assistant base URL |
| HA Token | — | Long-Lived Access Token |
| HA Sensors | — | Entity IDs for power, temperature, humidity |
| HA Poll Interval | `30 sec` | How often to refresh HA sensors |

---

## 📡 Monitoring Modes

Each app can be monitored using a separate URL/address with one of three modes:

| Mode | Example | How it works |
|------|---------|--------------|
| `URL` | `http://192.168.1.10:9000` | HTTP request — online if status < 500 |
| `IP` | `192.168.1.10` | TCP connect on port 80 |
| `IP:Port` | `192.168.1.10:9000` | TCP connect on the specified port |

> Self-signed and invalid SSL certificates are supported.

---

## 📁 Project Structure

```
homelabdash/
├── server.js              # Express entry point + cron scheduler
├── package.json
├── Dockerfile
├── docker-compose.yml
├── db/
│   └── database.js        # SQLite schema and initialization
├── routes/
│   ├── apps.js            # App bookmarks CRUD
│   ├── servers.js         # Server inventory CRUD
│   ├── settings.js        # Settings API
│   ├── monitor.js         # Status check logic
│   └── ha.js              # Home Assistant proxy
└── public/
    ├── index.html
    ├── css/style.css
    └── js/app.js
```

---

## 🔧 Useful Commands

```bash
# View logs
cd /opt/homelabdash && docker compose logs -f

# Restart
cd /opt/homelabdash && docker compose restart

# Stop
cd /opt/homelabdash && docker compose down

# Rebuild after manual file changes
cd /opt/homelabdash && docker compose up -d --build
```

---

## 📱 Compatibility

- **Browsers**: Chrome, Firefox, Safari
- **Devices**: Desktop, tablet, smartphone
- **Docker**: Compose v2
- **Proxmox**: Tested on PVE 8.x

---

## 📄 License

MIT — free to use, modify and distribute.
