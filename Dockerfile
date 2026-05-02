FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PORT=7681

RUN apt update && apt install -y --no-install-recommends \
    sudo vim curl wget git net-tools ca-certificates build-essential ttyd \
    python3 python3-pip python3-dev python3-venv \
    supervisor cron systemctl \
    && apt clean && rm -rf /var/lib/apt/lists/*

WORKDIR /root

# Cài đặt Python packages phổ biến
RUN pip3 install --no-cache-dir \
    requests flask django fastapi uvicorn \
    numpy pandas matplotlib scikit-learn \
    aiohttp websockets

# User authentication
ENV USERNAME=root
ENV PASSWORD=root123

# Tạo thư mục cho scripts
RUN mkdir -p /root/scripts /root/logs /root/apps

# Health check script
RUN cat > /root/scripts/health_check.sh << 'EOF'
#!/bin/bash
if pgrep -f ttyd > /dev/null; then
    exit 0
else
    exit 1
fi
EOF
RUN chmod +x /root/scripts/health_check.sh

# Auto restart script
RUN cat > /root/scripts/auto_restart.sh << 'EOF'
#!/bin/bash
while true; do
    if ! pgrep -f ttyd > /dev/null; then
        echo "$(date): ttyd crashed, restarting..." >> /root/logs/restart.log
        ttyd -p ${PORT} -c ${USERNAME}:${PASSWORD} bash
    fi
    sleep 30
done
EOF
RUN chmod +x /root/scripts/auto_restart.sh

# Supervisor config cho auto-restart
RUN cat > /etc/supervisor/conf.d/ttyd.conf << 'EOF'
[program:ttyd]
command=ttyd -p 7681 -c root:root123 bash
autostart=true
autorestart=true
stderr_logfile=/root/logs/ttyd.err.log
stdout_logfile=/root/logs/ttyd.out.log
user=root
EOF

# Cron job để giữ process sống
RUN cat > /root/scripts/keep_alive.py << 'EOF'
#!/usr/bin/env python3
import subprocess
import time
import logging

logging.basicConfig(filename='/root/logs/keep_alive.log', level=logging.INFO)

while True:
    try:
        result = subprocess.run(['pgrep', '-f', 'ttyd'], capture_output=True)
        if result.returncode != 0:
            logging.info(f"Process died, restarting at {time.strftime('%Y-%m-%d %H:%M:%S')}")
            subprocess.Popen(['ttyd', '-p', '7681', '-c', 'root:root123', 'bash'])
        time.sleep(60)
    except Exception as e:
        logging.error(f"Error: {e}")
        time.sleep(60)
EOF
RUN chmod +x /root/scripts/keep_alive.py

# Python script để monitor & auto-restart
RUN cat > /root/apps/monitor.py << 'EOF'
#!/usr/bin/env python3
import os
import subprocess
import time
from datetime import datetime

LOG_FILE = "/root/logs/monitor.log"

def log(msg):
    with open(LOG_FILE, "a") as f:
        f.write(f"[{datetime.now()}] {msg}\n")

def check_service():
    result = subprocess.run(["pgrep", "-f", "ttyd"], capture_output=True)
    return result.returncode == 0

def restart_service():
    os.system("pkill -f ttyd")
    time.sleep(2)
    os.system("ttyd -p 7681 -c root:root123 bash &")
    log("Service restarted")

if __name__ == "__main__":
    log("Monitor started")
    while True:
        try:
            if not check_service():
                log("Service down! Restarting...")
                restart_service()
            time.sleep(30)
        except Exception as e:
            log(f"Error: {e}")
            time.sleep(30)
EOF
RUN chmod +x /root/apps/monitor.py

# Entrypoint script
RUN cat > /root/start.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting services..."

# Tạo thư mục logs
mkdir -p /root/logs

# Start supervisor
/etc/init.d/supervisor start 2>/dev/null || supervisord -c /etc/supervisor/supervisord.conf &

# Start monitor script
python3 /root/apps/monitor.py &

# Start ttyd
exec ttyd -p ${PORT:-7681} -c ${USERNAME}:${PASSWORD} bash
EOF
RUN chmod +x /root/start.sh

EXPOSE 7681

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /root/scripts/health_check.sh

CMD ["/root/start.sh"]
