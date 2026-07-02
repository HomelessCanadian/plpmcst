# PLPMCST: Pank's Low Power Minecraft Server Toolkit

PLPMCST is a lightweight, high-efficiency suite of automation tools designed to run Minecraft servers on Linux hardware without wasting system resources. It features an automated multi-stage backup pipeline, automatic multi-world partition mapping, and a rate-limit-aware Discord console logging utility.

Built natively for Linux servers (Ubuntu/Mint/Debian) running **Vanilla, Paper, Purpur, or Fabric**.

---

## ✨ Features

* **💾 Automatic Backups - Creates compressed backups on a schedule without interrupting gameplay.
* **🛡️ Safe Backup Process - Temporarily pauses world saving to prevent corrupted backups.
* **🌍 Works with Vanilla, Paper, Purpur, and Fabric - Automatically detects your server layout.
* **💬 Discord Console Logging - Watch your server console from Discord, with sensitive information automatically hidden.
* **⚡ Low Performance Impact - Runs backups with the lowest CPU and disk priority so your server stays responsive.
* **⏰ Reliable Scheduling - Uses native Linux systemd timers instead of cron for dependable automation.

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

1. Place `.env`, `backup.sh`, `start.sh`, and `streamWebhook.py` directly into your desired install directory.
2. Open `.env` and fill in your paths and thresholds:
```bash
SERVER_ROOT="/path/to/your/server"
BACKUP_DIR="/path/to/your/backups"
INTERVAL_MINUTES=30
RETENTION_LIMIT=20
MAX_DISK=90
WEBHOOK_URL=""   # leave blank to ignore discord logging (local logs only)
```
3. **Activate Background Backups:** To latch the backup sequence directly onto your Linux hardware clock engine without starting from scratch, run the standalone scheduling utility:
```bash
chmod +x provision_timer.sh
./provision_timer.sh
```
If you ever need to run a backup on the fly, just run the `backup.sh` script manually:
```bash
./backup.sh
```
Now your launcher script is ready to serve your Minecraft session.
```bash
./start.sh
```
---

## ⚙️ Maintenance & Administration

Once installed, PLPMCST requires very little maintenance. The following commands can help you monitor or adjust the toolkit.

### 📅 Check the Backup Schedule

View when the next automatic backup will run:

```bash
systemctl list-timers | grep plpmcst
```

This displays the next scheduled execution time for the backup timer.

---

### 📜 View Backup Logs

Watch the backup service output live:

```bash
journalctl -u plpmcst-backup.service -f
```

Press **Ctrl+C** when you're finished viewing the logs.

To see previous backup runs instead of following live output:

```bash
journalctl -u plpmcst-backup.service
```

---

### ⚙️ Modify Configuration

All user-configurable settings are stored in `.env`.

Common settings include:

- Server location
- Backup destination
- Backup interval
- Backup retention limit
- Maximum disk usage warning
- Discord webhook URL
- tmux session names

Edit the file with your preferred text editor, for example:

```bash
nano .env
```

Most changes are picked up automatically the next time `backup.sh` runs—no restart is required.

> **Note:** If you're using a tunneling service other than Playit (such as Tailscale, ngrok, or your own startup script), you'll need to modify `start.sh` to launch it alongside the Minecraft server.

---

### 🖥️ Managing Your Server with tmux

PLPMCST launches your Minecraft server inside a **tmux** session, allowing it to continue running even after you disconnect from SSH.

If Playit support is enabled, `start.sh` also launches the Playit agent in a separate tmux session automatically.

By default, the session names are:

| Service | Default Session |
|---------|-----------------|
| Minecraft Server | `minecraft` |
| Playit Tunnel | `playit` |

Both session names can be changed in `.env`.

#### List running sessions

```bash
tmux ls
```

Example:

```text
minecraft: 1 windows
playit: 1 windows
```

#### Attach to the Minecraft console

```bash
tmux attach -t minecraft
```

You can now view the live server console and enter Minecraft commands directly.

#### Attach to the Playit console

```bash
tmux attach -t playit
```

This displays the Playit agent's output and connection status.

#### Leave a session without stopping it

Press:

```
Ctrl+B
```

then

```
D
```

This detaches from the session while leaving the program running.

> **Tip:** Closing your SSH window while attached may terminate the running process. Always detach (`Ctrl+B`, then `D`) before disconnecting.
