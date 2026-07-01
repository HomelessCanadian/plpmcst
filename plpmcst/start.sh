#!/bin/bash
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

JAR_PATH="$SERVER_ROOT/$SERVER_JAR"

if [ ! -f "$JAR_PATH" ]; then
    echo "❌ Could not locate server JAR:"
    echo "   $JAR_PATH"
    exit 1
fi

if [ "$ENABLE_PLAYIT" = "true" ]; then
    if ! tmux has-session -t "$PLAYIT_SESSION" 2>/dev/null; then
        echo "Starting Playit session $PLAYIT_SESSION..."
        tmux new-session -d -s "$PLAYIT_SESSION" "playit"
    else
        echo "Session '$PLAYIT_SESSION' already exists. Skipping."
    fi
fi

if ! tmux has-session -t "$MC_SESSION" 2>/dev/null; then
    echo "Starting Minecraft session $MC_SESSION..."

    mkdir -p "$LOG_DIR"

    CMD="$JAVA_BIN \
-Xms$JAVA_XMS \
-Xmx$JAVA_XMX \
$JAVA_FLAGS \
$AIKAR_FLAGS \
-jar \"$JAR_PATH\" \
$SERVER_ARGS \
2>&1 | tee /dev/tty | python3 -u \"$DIR/streamWebhook.py\" \"$WEBHOOK_URL\" \"$LOG_DIR\""

    tmux new-session -d -s "$MC_SESSION" -c "$SERVER_ROOT" "$CMD"
    echo "Waiting for server to init to force saving after possible backup malfunction (30 sec timer)"
    sleep 30
    tmux send-keys -t "$MC_SESSION" "save-on" Enter
else
    echo "Session '$MC_SESSION' already exists. Skipping."
fi
echo "Server launched. Use 'tmux ls' to see active sessions, 'tmux attach -t session_name' to view live output."
