#!/usr/bin/env bash
# Deskflow SERVER setup — the laptop with the physical keyboard/mouse.
# Ubuntu 22.04+ (tested on 26.04, GNOME Wayland via libei).
#
# Usage: ./setup-server.sh [server-screen-name] [client-screen-name] [side]
#   side = which edge of THIS screen reaches the other laptop: left|right|top|bottom (default: left)
set -euo pipefail

SERVER_NAME="${1:-$(hostname)}"
CLIENT_NAME="${2:-laptop2}"
SIDE="${3:-left}"
PORT=24800

CFG_DIR="$HOME/.config/Deskflow"
TLS_DIR="$CFG_DIR/tls"
SYSTEMD_DIR="$HOME/.config/systemd/user"
mkdir -p "$TLS_DIR" "$SYSTEMD_DIR"

command -v deskflow-core >/dev/null || { echo "Run: sudo apt install deskflow first"; exit 1; }

# --- TLS cert (self-signed, kept if already present) -------------------------
if [ ! -f "$TLS_DIR/deskflow.pem" ]; then
  openssl req -x509 -newkey rsa:2048 -sha256 -days 1095 -nodes \
    -subj "/CN=$SERVER_NAME" \
    -keyout "$TLS_DIR/deskflow.pem" -out "$TLS_DIR/deskflow.pem" 2>/dev/null
fi

# --- Core settings ------------------------------------------------------------
cat > "$CFG_DIR/Deskflow.conf" <<EOF
[core]
computerName=$SERVER_NAME
enableCore=true
mode=server
port=$PORT

[security]
tlsEnabled=true
certificate=$TLS_DIR/deskflow.pem
EOF

# --- Screen layout (edge wiring) ---------------------------------------------
case "$SIDE" in
  left)   BACK=right ;;
  right)  BACK=left ;;
  top)    BACK=bottom ;;
  bottom) BACK=top ;;
  *) echo "side must be left|right|top|bottom"; exit 1 ;;
esac

{
  echo "section: screens"
  printf '\t%s:\n' "$SERVER_NAME"
  printf '\t%s:\n' "$CLIENT_NAME"
  echo "end"
  echo ""
  echo "section: links"
  printf '\t%s:\n' "$SERVER_NAME"
  printf '\t\t%s = %s\n' "$SIDE" "$CLIENT_NAME"
  printf '\t%s:\n' "$CLIENT_NAME"
  printf '\t\t%s = %s\n' "$BACK" "$SERVER_NAME"
  echo "end"
  echo ""
  echo "section: options"
  printf '\tkeystroke(super+a) = lockCursorToScreen(toggle)\n'
  printf '\tswitchDoubleTap = 250\n'
  printf '\tswitchCorners = none\n'
  printf '\tswitchCornerSize = 0\n'
  echo "end"
} > "$CFG_DIR/deskflow-server.conf"

# --- User service (autostart at login) ---------------------------------------
cat > "$SYSTEMD_DIR/deskflow.service" <<EOF
[Unit]
Description=Deskflow input server
After=graphical-session.target

[Service]
ExecStart=/usr/bin/deskflow-core server
Restart=on-failure

[Install]
WantedBy=graphical-session.target
EOF

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
systemctl --user daemon-reload
systemctl --user enable --now deskflow.service

echo
echo "== SERVER UP =="
echo "screen name : $SERVER_NAME  (peer: $CLIENT_NAME via $SIDE edge)"
ss -tln | grep -q ":$PORT " && echo "listening   : port $PORT OK" || echo "WARNING     : port $PORT not listening yet"
echo
echo "== YOUR cert fingerprint (send this to the CLIENT machine):"
openssl x509 -in "$TLS_DIR/deskflow.pem" -noout -fingerprint -sha256
echo
echo "== When the client sends you ITS fingerprint, pin it with:"
echo "   echo \"v2:sha256:<64-hex-lowercase>\" >> $TLS_DIR/trusted-clients"
echo "   systemctl --user restart deskflow"
