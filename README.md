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

## 🚀 Automatic Installation (Recommended)

The easiest way to deploy the toolkit is to use the self-contained, interactive bundle wrapper. It automatically audits your system dependencies, creates your directories, configures local environment spaces, and hooks up the background scheduling engines.

1. Download or move `install_plpmcst.sh` to your server.
2. Grant execution permissions and run the wizard:
   ```bash
   chmod +x install_plpmcst.sh
   ./install_plpmcst.sh

```

3. Follow the interactive terminal prompts to select your operational configurations.

---

## 🛠️ Manual Installation / Updates

If you prefer to configure your environment paths manually, or you declined system automation features during the initial installation wizard:

1. Extract the toolkit payload files directly into your desired directory folder space.
2. Open `backup.sh` in a text editor and replace the `##INJECT_...##` variables at the top of the file with your paths and thresholds:
```bash
SERVER_ROOT="/path/to/your/server"
BACKUP_DIR="/path/to/your/backups"
INTERVAL_MINUTES=30
RETENTION_LIMIT=20
MAX_DISK=90

```


3. If using Discord integration, create a file named `.env` in the toolkit folder and supply your webhook profile:
```bash
WEBHOOK_URL="https://discord.com/api/webhooks/your_token_string"

```


4. **Activate Background Backups:** To latch the backup sequence directly onto your Linux hardware clock engine without starting from scratch, run the standalone scheduling utility helper:
```bash
chmod +x register-timer.sh
./register-timer.sh

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
Simply edit the custom variable settings embedded inside `backup.sh` or swap the webhook destination link pointing to your Discord chat platform directly inside your hidden `.env` file environment. No full system reinstallation is required!