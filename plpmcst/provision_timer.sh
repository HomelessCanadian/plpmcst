#!/bin/bash
# --- PLPMCST: Systemd Timer Registration Utility ---
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$DIR/.env" ]; then
    source "$DIR/.env"
else
    echo "❌ .env not found."
    exit 1
fi
BACKUP_SCRIPT="$DIR/backup.sh"
RUN_USER="${SUDO_USER:-$(whoami)}"

echo "=== PLPMCST Systemd Timer Installer ==="

# 1. Verification Safeguard
if [ ! -f "$BACKUP_SCRIPT" ]; then
    echo "❌ Error: Could not locate 'backup.sh' in the same folder."
    echo "Please ensure this script runs directly from your plpmcst toolkit directory."
    exit 1
fi

# 2. FIX: INTERVAL_MINUTES already lives in .env (sourced above) — no need to
# grep it out of backup.sh, which never actually contained it.
if [ -z "$INTERVAL_MINUTES" ] || [[ ! "$INTERVAL_MINUTES" =~ ^[0-9]+$ ]]; then
    echo "⚠️  Could not auto-detect a valid backup interval."
    read -p "Enter backup clock execution window (in minutes, e.g., 30): " INTERVAL_MINUTES
fi

echo "📍 Target Script Path: $BACKUP_SCRIPT"
echo "⏱️  Target Execution Clock: Run every $INTERVAL_MINUTES minutes"
echo ""

# 3. Request elevation permissions and apply provisioning profiles
echo "Registering systemd service and timer (Requires root elevation)..."

cat <<EOF | sudo tee /etc/systemd/system/plpmcst-backup.service > /dev/null
[Unit]
Description=PLPMCST Minecraft Automated Backup Task
After=network.target

[Service]
Type=oneshot
User=$RUN_USER
ExecStart=$BACKUP_SCRIPT
EOF

cat <<EOF | sudo tee /etc/systemd/system/plpmcst-backup.timer > /dev/null
[Unit]
Description=Run PLPMCST Minecraft Backup every $INTERVAL_MINUTES minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=${INTERVAL_MINUTES}min
Unit=plpmcst-backup.service
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable plpmcst-backup.timer
sudo systemctl start plpmcst-backup.timer

echo ""
echo "✅ Systemd automation service successfully built and engaged!"
echo "⏱️  Track active clock windows anytime via: systemctl list-timers | grep plpmcst"
echo "🪵  Audit live backend logs via: journalctl -u plpmcst-backup.service"
echo ""
