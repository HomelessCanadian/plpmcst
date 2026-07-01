import sys, requests, time, re, os

WEBHOOK_URL = sys.argv[1]
buffer = []
last_send = time.time()
pending_warning = "" 
ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')

# --- PORTABILITY LOGIC ---
# Dynamically locate the directory where THIS script lives
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_DIR = os.path.join(SCRIPT_DIR, "logs")
STATS_LOG = os.path.join(LOG_DIR, "webhook_stats.log")

# Ensure the logs directory exists before writing to it
os.makedirs(LOG_DIR, exist_ok=True)

def clean_line(line):
    # 1. Remove ANSI color codes
    line = ansi_escape.sub('', line)
    # 2. STRIP BACKTICKS: This prevents players from breaking the code block
    line = line.replace("`", "")
    # 3. REDACT IPv4 + Ports (e.g., 123.45.67.89:54321)
    ipv4_port_pattern = r'/?\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(?::\d+)?\b'
    line = re.sub(ipv4_port_pattern, "[REDACTED-IP]", line)
    # 4. REDACT IPv6 + Ports (e.g., [2001:db8::1]:54321 or 2001:db8::1)
    ipv6_pattern = r'(?<!^\[)(?:([0-9a-fA-F]{1,4}:){3,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|::)(?::\d+)?'
    line = re.sub(ipv6_pattern, "[REDACTED-IPV6]", line)
    return line

def send_to_discord(data):
    global pending_warning
    
    final_message = f"{pending_warning}```\n{data}\n```"
    payload = {"content": final_message}
    
    try:
        response = requests.post(WEBHOOK_URL, json=payload, timeout=10)
        if response.status_code == 429:
            retry_after = response.json().get('retry_after', 5000) / 1000
            
            # Use our dynamic portable path here instead of the hardcoded one
            with open(STATS_LOG, "a") as f:
                f.write(f"{time.ctime()}: RATE LIMIT HIT. Delayed {retry_after}s\n")
            
            pending_warning = f"⚠️ [RATE LIMIT HIT: Logs delayed by {retry_after}s]\n"
            time.sleep(retry_after)
            send_to_discord(data) 
        else:
            pending_warning = ""
    except Exception as e:
        print(f"!!! p4nk-pipe: Network Error: {e}")

print("p4nk-pipe: Active. Streaming to Discord (Sanitized Blocks)...")

for line in sys.stdin:
    line = clean_line(line)
    print(line, end="") 
    buffer.append(line.strip())
    
    # Send every 2 seconds or if hitting Discord's char limit (1800 to be safe)
    if len("\n".join(buffer)) > 1800 or (time.time() - last_send > 2 and buffer):
        send_to_discord("\n".join(buffer))
        buffer = []
        last_send = time.time()