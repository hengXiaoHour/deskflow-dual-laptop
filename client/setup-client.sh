#!/usr/bin/env bash
# Deskflow CLIENT setup — the laptop that gets controlled over the network.
# Ubuntu 22.04+ (tested on 26.04, GNOME Wayland via libei).
#
# Usage: ./setup-client.sh <SERVER_IP> [client-screen-name]
set -euo pipefail

SERVER_IP="${1:?Usage: ./setup-client.sh <SERVER_IP> [client-screen-name]}"
CLIENT_NAME="${2:-laptop2}"
PORT=24800

CFG_DIR="$HOME/.config/Deskflow"
TLS_DIR="$CFG_DIR/tls"
SYSTEMD_DIR="$HOME/.config/systemd/user"
mkdir -p "$TLS_DIR" "$SYSTEMD_DIR"

command -v deskflow-core >/dev/null || { echo "Run: sudo apt install deskflow first"; exit 1; }

# --- TLS cert (self-signed, kept if already present) -------------------------
if [ ! -f "$TLS_DIR/deskflow.pem" ]; then
  openssl req -x509 -newkey rsa:2048 -sha256 -days 1095 -nodes \
    -subj "/CN=$CLIENT_NAME" \
    -keyout "$TLS_DIR/deskflow.pem" -out "$TLS_DIR/deskflow.pem" 2>/dev/null
fi

# --- Core settings ------------------------------------------------------------
cat > "$CFG_DIR/Deskflow.conf" <<EOF
[core]
computerName=$CLIENT_NAME
mode=client
port=$PORT

[client]
remoteHost=$SERVER_IP

[security]
tlsEnabled=true
certificate=$TLS_DIR/deskflow.pem
EOF

# --- User service (autostart at login) ---------------------------------------
cat > "$SYSTEMD_DIR/deskflow-client.service" <<EOF
[Unit]
Description=Deskflow input client
After=graphical-session.target

[Service]
ExecStart=/usr/bin/deskflow-core client
Restart=on-failure

[Install]
WantedBy=graphical-session.target
EOF

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
systemctl --user daemon-reload
systemctl --user enable --now deskflow-client.service

echo
echo "== CLIENT UP =="
echo "screen name : $CLIENT_NAME  (server: $SERVER_IP:$PORT)"
echo
echo "== YOUR cert fingerprint (send this to the SERVER machine):"
openssl x509 -in "$TLS_DIR/deskflow.pem" -noout -fingerprint -sha256
echo
echo "== The SERVER must pin your fingerprint (there), and YOU must pin"
echo "== the server's fingerprint (here). Get it from the server operator, then:"
echo "   echo \"v2:sha256:<64-hex-lowercase>\" >> $TLS_DIR/trusted-servers"
echo "   systemctl --user restart deskflow-client"
