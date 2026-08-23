# deskflow-dual-laptop

One keyboard + mouse controlling two Ubuntu laptops over LAN with
[Deskflow](https://github.com/deskflow/deskflow) (open-source Synergy/Barrier
successor). TLS-encrypted, mutual fingerprint pinning, autostarts at login.
Works on **GNOME Wayland** (uses libei — no X11 fallback needed).

Tested: Ubuntu 26.04 → 26.04, Deskflow 1.26 (apt), server on GNOME Wayland.

```
┌──────────────┐  LAN :24800  ┌──────────────┐
│  LAPTOP A    │◄────────────►│  LAPTOP B    │
│ keyboard+    │   TLS 1.3    │ receives     │
│ mouse (BT)   │              │ input        │
└──────────────┘              └──────────────┘
     SERVER                        CLIENT
```

Your Bluetooth keyboard/mouse stay paired to the server laptop only. The
client needs no peripherals at all.

## Quick start

**On both laptops** (once):
```bash
sudo apt install deskflow
```

**Server** = the machine with the physical keyboard/mouse:
```bash
cd server
./setup-server.sh "$(hostname)" laptop2 left
#                     ↑ screen name      ↑ peer name  ↑ which edge of THIS
#                                                    screen reaches the peer
```

**Client** = the other machine:
```bash
cd client
./setup-client.sh <SERVER_IP> laptop2
```

**Exchange fingerprints** (each script prints its own at the end):

1. Server pins the *client's* fingerprint:
   ```bash
   echo "v2:sha256:<client-fingerprint-hex>" >> ~/.config/Deskflow/tls/trusted-clients
   systemctl --user restart deskflow
   ```
2. Client pins the *server's* fingerprint:
   ```bash
   echo "v2:sha256:<server-fingerprint-hex>" >> ~/.config/Deskflow/tls/trusted-servers
   systemctl --user restart deskflow-client
   ```

Fingerprint hex = lowercase, no colons. The `openssl x509 -fingerprint` output
gives you `AA:BB:...` — just lowercase it and strip the `:` characters.

Done. Slam your cursor into the configured edge of the server screen and it
teleports to the client. Keyboard and clipboard follow.

## Getting fingerprints without a shell one-liner

Each setup script prints its fingerprint. To re-print later:

```bash
openssl x509 -in ~/.config/Deskflow/tls/deskflow.pem -noout -fingerprint -sha256
```

## Switching behavior (server config)

Edit `~/.config/Deskflow/deskflow-server.conf`, then
`systemctl --user restart deskflow`.

| Option | Meaning |
|---|---|
| `switchDelay = 300` | cursor must dwell at the edge this many ms before switching. `0` = instant slam |
| `switchDoubleTap = 250` | must tap the edge twice quickly instead of dwelling |
| `switchNeedsShift = true` | only switch while holding Shift (also `Ctrl` / `Alt`) |
| `switchCorners` / `switchCornerSize` | dead-zone screen corners so they never trigger |

Edge wiring lives in the `section: links` block:
```ini
section: links
	HOSTNAME_A:
		left = HOSTNAME_B     # A's left edge -> B
	HOSTNAME_B:
		right = HOSTNAME_A    # B's right edge -> back to A
end
```

Keyboard-only switching (no edge crossing at all):
```ini
switchDoubleTap = -1          # effectively disable edge switching
keystroke(super+shift+right) = switchInDirection(right)
```

Handy keys:
- `Super+A` — lock/unlock cursor to current screen (panic key, set up by these scripts)
- Clipboard is shared both directions automatically

## Files created (both machines)

| Path | Purpose |
|---|---|
| `~/.config/Deskflow/Deskflow.conf` | mode/server-address/TLS settings |
| `~/.config/Deskflow/deskflow-server.conf` | server-only: screen layout + options |
| `~/.config/Deskflow/tls/deskflow.pem` | self-signed cert (cert+key in one file) |
| `~/.config/Deskflow/tls/trusted-clients` | server's allowlist of client certs |
| `~/.config/Deskflow/tls/trusted-servers` | client's allowlist of the server cert |
| `~/.config/systemd/user/deskflow(.client).service` | user service, autostart |

## Troubleshooting

```bash
journalctl --user -u deskflow -f          # server log
journalctl --user -u deskflow-client -f   # client log
ss -tln | grep 24800                      # server listening?
```

| Symptom | Likely cause / fix |
|---|---|
| `fingerprint does not match trusted fingerprint` | peer cert not pinned yet — add the `v2:sha256:...` line to the right trust DB |
| `server refused client with name ...` | client's `computerName` isn't listed in the server's `section: screens` |
| Connects then times out at hello | versions mismatch or firewall; check both run the same deskflow package |
| Cursor won't cross on Wayland first try | GNOME input-control dialog waiting on a screen — press Allow once |
| Nothing listens on 24800 from outside | open the port: `sudo ufw allow 24800/tcp` (if ufw enabled) |
| IP changed after reboot | prefer a hostname.reservation on the router, or use Avahi name `host.local` in `[client] remoteHost` |

## Uninstall

```bash
systemctl --user disable --now deskflow        # or deskflow-client
rm -r ~/.config/Deskflow ~/.config/systemd/user/deskflow*.service
systemctl --user daemon-reload
```

## License

MIT for the scripts here; Deskflow itself is GPL-2.0-or-later.
