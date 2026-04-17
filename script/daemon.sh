#!/bin/sh

INIT="/etc/init.d/modwebextra"
RCS_LINK="/etc/rcS.d/S99modwebextra"
MOD_HOME="/home/mod"
TELNET_FLAG="$MOD_HOME/telnet"
TTL_FLAG="$MOD_HOME/ttl"

mkdir -p /etc/init.d /etc/rcS.d "$MOD_HOME"
rm -f "$MOD_HOME/modweb.log" "$MOD_HOME/modwebextra.log"

[ -f "$TELNET_FLAG" ] || echo 1 > "$TELNET_FLAG"
[ -f "$TTL_FLAG" ] || : > "$TTL_FLAG"

cat > "$INIT" << 'EOF'
#!/bin/sh

PATH="/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
export PATH

MOD_HOME="/home/mod"
TELNET_FLAG="$MOD_HOME/telnet"
TTL_FLAG="$MOD_HOME/ttl"

run_iptables() {
    if command -v iptables >/dev/null 2>&1; then
        iptables "$@"
        return $?
    fi
    for b in /usr/sbin/iptables /sbin/iptables /usr/bin/iptables /bin/iptables; do
        if [ -x "$b" ]; then
            "$b" "$@"
            return $?
        fi
    done
    return 127
}

run_telnetd() {
    killall telnetd >/dev/null 2>&1 || true
    telnetd -l /bin/sh -p 23 >/dev/null 2>&1
    return $?
}

telnet_running() {
    pgrep -x telnetd >/dev/null 2>&1 || ps w | grep '[t]elnetd' >/dev/null 2>&1
}

get_telnet_flag() {
    if [ ! -f "$TELNET_FLAG" ]; then
        printf "0"
        return
    fi
    val="$(tr -d '\r\n\t ' < "$TELNET_FLAG" 2>/dev/null)"
    [ "$val" = "1" ] && printf "1" || printf "0"
}

get_ttl_flag() {
    if [ ! -f "$TTL_FLAG" ]; then
        printf ""
        return
    fi
    tr -d '\r\n\t ' < "$TTL_FLAG" 2>/dev/null
}

clear_ttl_rules() {
    rules="$(run_iptables -t mangle -S POSTROUTING 2>/dev/null)"
    [ $? -eq 0 ] || return 0
    while :; do
        cur="$(printf "%s\n" "$rules" | awk '/--ttl-set/{print $NF}' | tail -n 1)"
        [ -z "$cur" ] && break
        run_iptables -t mangle -D POSTROUTING -j TTL --ttl-set "$cur" >/dev/null 2>&1 || break
        rules="$(run_iptables -t mangle -S POSTROUTING 2>/dev/null)"
    done
}

start_telnet() {
    run_telnetd
}

stop_telnet() {
    killall telnetd >/dev/null 2>&1 || true
}

apply_telnet_from_flag() {
    if [ "$(get_telnet_flag)" = "1" ]; then
        start_telnet
    else
        stop_telnet
    fi
}

apply_ttl_from_flag() {
    ttl="$(get_ttl_flag)"
    clear_ttl_rules
    [ -n "$ttl" ] || return 0
    case "$ttl" in *[!0-9]*) return 0 ;; esac
    if [ "$ttl" -lt 1 ] || [ "$ttl" -gt 255 ]; then
        return 0
    fi
    run_iptables -t mangle -A POSTROUTING -j TTL --ttl-set "$ttl" >/dev/null 2>&1
    return $?
}

status() {
    tflag="$(get_telnet_flag)"
    ttlflag="$(get_ttl_flag)"
    [ -n "$ttlflag" ] || ttlflag="-"
    if telnet_running; then
        tstate="running"
    else
        tstate="stopped"
    fi
    ttl_now="$(run_iptables -t mangle -S POSTROUTING 2>/dev/null | awk '/--ttl-set/{print $NF}' | tail -n 1)"
    [ -n "$ttl_now" ] || ttl_now="-"
    echo "telnet_flag=$tflag telnet_state=$tstate ttl_flag=$ttlflag ttl_runtime=$ttl_now"
}

case "$1" in
    start)
        [ -f "$TELNET_FLAG" ] || echo 1 > "$TELNET_FLAG"
        [ -f "$TTL_FLAG" ] || : > "$TTL_FLAG"
        apply_telnet_from_flag
        apply_ttl_from_flag
        (
            sleep 20
            apply_telnet_from_flag
        ) >/dev/null 2>&1 &
        ;;
    stop)
        :
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
exit 0
EOF

chmod 755 "$INIT"
rm -f /etc/rcS.d/S99modwebextra /etc/rcS.d/S98modwebextra
ln -sf "$INIT" "$RCS_LINK"

"$INIT" start >/dev/null 2>&1 || true

echo "Autostart installed:"
echo "  init script: $INIT"
echo "  startup link: $RCS_LINK"
echo "  telnet flag : $TELNET_FLAG (1=on,0=off)"
echo "  ttl flag    : $TTL_FLAG (empty=skip, 1..255=apply)"
