#!/bin/bash
# --- PLPMCST: Backup Core ---
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$DIR/.env" ]; then
    source "$DIR/.env"
else
    echo "❌ .env not found."
    exit 1
fi

SERVER_JAR=$(find "$SERVER_ROOT" -maxdepth 1 \
    -type f \
    \( -name "*.jar" ! -name "*installer*" ! -name "*api*" \) \
    -printf "%f\n" | head -n1)

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")

# Setup local structure if missing
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

# Redirect stdout and stderr to the log file
exec > >(tee -a "$LOG_FILE") 2>&1

send_webhook() {
    if [ -n "$WEBHOOK_URL" ]; then
        # FIX: pass LOG_DIR through so streamWebhook.py knows where to write its own logs
        echo "[BACKUP REPORT]: $1" | python3 "$DIR/streamWebhook.py" "$WEBHOOK_URL" "$LOG_DIR"
    else
        echo "[LOCAL REPORT]: $1"
    fi
}

check_disk_space() {
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
TARGET_WORLDS=$(ls -d \
    "$WORLD_NAME" \
    "${WORLD_NAME}_nether" \
    "${WORLD_NAME}_the_end" \
    2>/dev/null)

# --- INTERVAL & ONLINE CHECK ---
if ! tmux has-session -t "$MC_SESSION" 2>/dev/null; then
    echo "$(date): [INFO] Server is offline. Checking for recent changes before skipping..."

    RECENT_CHANGES=$(find "$WORLD_NAME/level.dat" -mmin -"${INTERVAL_MINUTES}" 2>/dev/null | wc -l)

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
    read -r OLD_HASH < "$HASH_FILE"
else
    OLD_HASH="none"
fi

if [[ "$NEW_HASH" == "$OLD_HASH" ]]; then
    echo "$(date): [SKIP] World unchanged. No backup needed."
    send_webhook "[SKIP] World unchanged."
    exit 0
fi

# --- SERVER INTERACTION ---
if tmux has-session -t "$MC_SESSION" 2>/dev/null; then
    echo "$(date): [INFO] Change detected. Freezing world..."
    tmux send-keys -t "$MC_SESSION" "say [PLPMCST] Backup starting..." Enter
    sleep 1
    tmux send-keys -t "$MC_SESSION" "save-all" Enter
    sleep 2
    tmux send-keys -t "$MC_SESSION" "save-off" Enter
else
    echo "$(date): [INFO] Server offline but changes pending. Skipping console freeze commands."
fi

# --- THE BACKUP (Individual Dimensions) ---
for FOLDER in $TARGET_WORLDS; do
    echo "$(date): [INFO] Compressing $FOLDER..."
    nice -n 19 ionice -c 3 tar -czf "$BACKUP_DIR/${FOLDER}_$TIMESTAMP.tar.gz" "$FOLDER"
done

# --- UNFREEZE ---
if tmux has-session -t "$MC_SESSION" 2>/dev/null; then
    tmux send-keys -t "$MC_SESSION" "save-on" Enter
    tmux send-keys -t "$MC_SESSION" "say [PLPMCST] Backup complete!" Enter
fi

# --- FINALIZE & ROTATE ---
echo "$NEW_HASH" > "$HASH_FILE"
echo "$TIMESTAMP $NEW_HASH" >> "$HASH_LOG"

for TYPE in \
    "$WORLD_NAME" \
    "${WORLD_NAME}_nether" \
    "${WORLD_NAME}_the_end"; do
    ls -t "$BACKUP_DIR"/${TYPE}_* 2>/dev/null | tail -n +"$((RETENTION_LIMIT + 1))" | xargs rm -f 2>/dev/null
done

echo "$(date): [SUCCESS] Backup saved for $TIMESTAMP"
send_webhook "✅ [SUCCESS] Backup complete. Dimensions saved: $TARGET_WORLDS"
check_disk_space
