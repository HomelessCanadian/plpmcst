#!/bin/bash
# --- PLPMCST: Pank's Low Power Minecraft Server Toolkit ---

# !!!--- CONFIGURATION ---!!!
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_ROOT="##INJECT_SERVER_ROOT##"
BACKUP_DIR="##INJECT_BACKUP_DIR##"
INTERVAL_MINUTES=##INJECT_INTERVAL##
RETENTION_LIMIT=##INJECT_RETENTION##
MAX_DISK=##INJECT_MAXDISK## # percentage of disk space before warning


# Setup local structure if missing
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
HASH_FILE="$BACKUP_DIR/.last_hash"
HASH_LOG="$BACKUP_DIR/.hashlog"
TMUX_SESSION="minecraft"
TMUX_CMD="/usr/bin/tmux -S /tmp/tmux-$(id -u)/default"

# Load Webhook securely from a hidden local environment file
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    WEBHOOK_URL="" 
fi



# Redirect stdout and stderr to the log file
exec > >(tee -a "$LOG_FILE") 2>&1

send_webhook() {
    if [ -n "$WEBHOOK_URL" ]; then
        echo "[BACKUP REPORT]: $1" | python3 "$SCRIPT_DIR/streamWebhook.py" "$WEBHOOK_URL"
    else
        echo "[LOCAL REPORT]: $1"
    fi
}

check_disk_space() {
    # Dynamically find the mount point of the server root
    USAGE=$(df "$SERVER_ROOT" | tail -1 | awk '{print $5}' | sed 's/%//')
    THRESHOLD=$MAX_DISK 
    if [ "$USAGE" -gt "$THRESHOLD" ]; then
        send_webhook "🚨 WARNING: Disk space is critically low! ($USAGE% used)."
    fi
}

send_error() {
    export DISPLAY=:0
    export XAUTHORITY="$HOME/.Xauthority"
    export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
    
    if command -v notify-send &> /dev/null; then
        /usr/bin/notify-send -u critical "PLPMCST Error!" "Backup failed at line $1. Check $LOG_FILE"
    fi
    echo "$(date): [ERROR] Script failed at line $1"
    send_webhook "[BACKUP] Backup failed at line $1. Check $LOG_FILE"
}

set -o errtrace
trap 'send_error $LINENO' ERR

cd "$SERVER_ROOT" || exit 1

# --- AUTOMATIC DIMENSION DETECTION ---
TARGET_WORLDS=$(ls -d world world_nether world_the_end 2>/dev/null)

# --- INTERVAL & ONLINE CHECK ---
if ! $TMUX_CMD has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo "$(date): [INFO] Server is offline. Checking for recent changes before skipping..."
    
    RECENT_CHANGES=$(find world/level.dat -mmin -"$INTERVAL_MINUTES" 2>/dev/null | wc -l)
    
    if [ "$RECENT_CHANGES" -eq 0 ]; then
        echo "$(date): [SKIP] Server is offline and idle beyond the interval window. Skipping backup."
        send_webhook "[SKIP] Server offline/idle."
        exit 0
    fi
    echo "$(date): [INFO] Server recently stopped. Proceeding with final offline backup."
fi

echo "$(date): [INFO] Starting hash check..."

# --- HASH CHECK ---
NEW_HASH=$(find $TARGET_WORLDS -type f ! -name "level.dat*" -print0 | xargs -0 sha256sum | sort | sha256sum | awk '{print $1}')

if [ -f "$HASH_FILE" ]; then
    OLD_HASH=$(cat "$HASH_FILE")
else
    OLD_HASH="none"
fi

if [ "$NEW_HASH" == "$OLD_HASH" ]; then
    echo "$(date): [SKIP] World unchanged. No backup needed."
    send_webhook "[SKIP] World unchanged."
    exit 0
fi

# --- SERVER INTERACTION ---
if $TMUX_CMD has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo "$(date): [INFO] Change detected. Freezing world..."
    $TMUX_CMD send-keys -t "$TMUX_SESSION" "say [PLPMCST] Backup starting..." Enter
    $TMUX_CMD send-keys -t "$TMUX_SESSION" "save-all" Enter
    sleep 3
    $TMUX_CMD send-keys -t "$TMUX_SESSION" "save-off" Enter
else
    echo "$(date): [INFO] Server offline but changes pending. Skipping console freeze commands."
fi

# --- THE BACKUP (Individual Dimensions) ---
for FOLDER in $TARGET_WORLDS; do
    echo "$(date): [INFO] Compressing $FOLDER..."
    nice -n 19 ionice -c 3 tar -czf "$BACKUP_DIR/${FOLDER}_$TIMESTAMP.tar.gz" "$FOLDER"
done

# --- UNFREEZE ---
if $TMUX_CMD has-session -t "$TMUX_SESSION" 2>/dev/null; then
    $TMUX_CMD send-keys -t "$TMUX_SESSION" "save-on" Enter
    $TMUX_CMD send-keys -t "$TMUX_SESSION" "say [PLPMCST] Backup complete!" Enter
fi

# --- FINALIZE & ROTATE ---
echo "$NEW_HASH" > "$HASH_FILE"
echo "$TIMESTAMP $NEW_HASH" >> "$HASH_LOG"

# Dynamically use the retention limit injected by the installer
for TYPE in world world_nether world_the_end; do
    ls -t "$BACKUP_DIR"/${TYPE}_* 2>/dev/null | tail -n +"$((RETENTION_LIMIT + 1))" | xargs rm -f 2>/dev/null
done

echo "$(date): [SUCCESS] Backup saved for $TIMESTAMP"
send_webhook "✅ [SUCCESS] Backup complete. Dimensions saved: $TARGET_WORLDS"
check_disk_space