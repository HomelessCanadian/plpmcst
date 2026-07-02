# PLPMCST: Pank's Low Power Minecraft Server Toolkit

PLPMCST is a lightweight, high-efficiency suite of automation tools designed to run Minecraft servers on Linux hardware without wasting system resources. It features an automated multi-stage backup pipeline, automatic multi-world partition mapping, and a rate-limit-aware Discord console logging utility.

Built natively for Linux servers (Ubuntu/Mint/Debian) running **Vanilla, Paper, Purpur, or Fabric**.

---

## ✨ Features

* **Low-Resource Footprint:** Uses `nice -n 19` and `ionice -c 3` background compression profiles to guarantee your server's TPS never drops during live backup tasks.
* **Smart State Engine:** Interacts natively with `tmux` to freeze the game world via `save-off` during disk compression, ensuring zero file corruption.
* **Adaptive Environment Mapper:** Automatically detects whether your installation uses isolated dimension mapping (Paper split layout) or bundled folders (Vanilla/Fabric standard layouts) and scales backups automatically.
* **p4nk-pipe Stream Buffer:** A secure Python pipeline that streams server terminal logs straight to Discord while stripping Markdown injection bugs (backticks) and redacting explicit internal IPv4/IPv6 address footprints.
* **Systemd Daemons:** Native background timing using system clocks instead of resource-heavy sleep loops or flaky crontabs.

---

## 📋 Prerequisites

While the interactive installer will automatically audit your system and attempt to configure dependencies, ensuring the following packages are present will guarantee a seamless setup:

* **System Utilities:** `tmux` (required for server console targeting)
* **Python Environment:** `python3` and the `requests` library (required for Discord webhooks)
* **Optional:** `libnotify-bin` (for native Linux desktop alert popups)

On Debian/Ubuntu-based systems, you can quickly verify or install them all with:
```bash
sudo apt update && sudo apt install tmux python3 python3-requests libnotify-bin -y
```
For you harcore users:
```bash
sudo pacman -Syu tmux python python-requests libnotify --noconfirm
```
```bash
sudo dnf install tmux python3 python3-requests libnotify -y
```
```bash
sudo zypper install tmux python3 python3-requests libnotify-tools -y
```
---

## 🚀 Automatic Installation (Recommended)

The easiest way to deploy the toolkit is to use the self-contained, interactive install wizard (`plpmcst-installer.sh`). It's a single file with a compressed copy of the entire utility.

1. Download or move `plpmcst-installer.sh` to your server.
2. Grant execution permissions (if necessary) and run the wizard:
```bash
   chmod +x plpmcst-installer.sh
   ./plpmcst-installer.sh
```
3. Follow the interactive terminal prompts to select your operational configurations.

The wizard creates `.env` (your full config) and drops `backup.sh`, `start.sh`, `provision_timer.sh`, and `streamWebhook.py` alongside it in your chosen install directory.

**Before trusting a copy of the installer**, especially since it runs `sudo` for the systemd step, verify it against a known-good hash:
```bash
sha256sum plpmcst-installer.sh
93893515934f01206f93c33e82e788459cea8e335a51c1ab22490a158ca7fc58 plpmcst-install.sh
```

---

## 🛠️ Manual Installation / Updates

If you prefer to configure your environment paths manually, or you declined system automation features during the initial installation wizard:

1. Place `env.template`, `backup.sh`, `start.sh`, `provision_timer.sh`, and `streamWebhook.py` directly into your desired install directory.
2. Rename `env.template` to `.env`, then open it and fill in your paths and thresholds:
```bash
SERVER_ROOT="/path/to/your/server"
BACKUP_DIR="/path/to/your/backups"
INTERVAL_MINUTES=30
RETENTION_LIMIT=20
MAX_DISK=90
WEBHOOK_URL=""   # leave blank to log locally instead of to Discord
```
3. **Activate Background Backups:** To latch the backup sequence directly onto your Linux hardware clock engine without starting from scratch, run the standalone scheduling utility:
```bash
chmod +x provision_timer.sh
./provision_timer.sh
```

---

## ⚙️ Maintenance & Administration

Once the native system architecture is locked down, you can audit, analyze, or tweak the operational background infrastructure using standard system commands:

* **Check Upcoming Backup Schedules:**
```bash
systemctl list-timers | grep plpmcst
```

* **Review Live Service Execution Output Logs:**
```bash
journalctl -u plpmcst-backup.service -f
```

* **Modify Configuration Details Later:**
Edit `.env` in your install directory - backup thresholds, server path, retention count, disk warning %, and the Discord webhook link all live there. `backup.sh` reads it fresh on every run, so no restart is required.
