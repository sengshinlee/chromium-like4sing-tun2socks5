#!/bin/bash

declare -g SERVER_PUBLIC_IP="$(curl -s https://cloudflare.com/cdn-cgi/trace | grep ip | awk -F '=' '{ print $2 }')"
declare -g SERVER_PUBLIC_NIC="$(ip -4 -o route get 1.1.1.1 | awk '{ print $5 }')"


function distribution() {
    if [ ! -f "/etc/debian_version" ]; then
        echo "ERROR: Linux distribution must be Ubuntu!"
        exit 1
    fi
}

function root() {
    if [ "$(echo ${USER})" != "root" ]; then
        echo "WARNING: You must be root to run the script!"
        exit 1
    fi
}

function install_sing-box() {
    local HOSTNAME="$(hostname)"

    if [ -f "/usr/bin/sing-box" ]; then
        echo "NOTICE: The sing-box binary file is installed, no need to reinstall!"
    else
        if [ "${HOSTNAME}" == "pikvm" ] || \
           [ "${HOSTNAME}" == "cmcc" ] || \
           [ "${HOSTNAME}" == "verizon" ] || \
           [ "${HOSTNAME}" == "at&t" ] || \
           [ "${HOSTNAME}" == "t-mobile" ] || \
           [ "${HOSTNAME}" == "aws" ] || \
           [ "${HOSTNAME}" == "us-west-1a" ] || \
           [ "${HOSTNAME}" == "us-west-2a" ] || \
           [ "${HOSTNAME}" == "us-west-2-wl1-sfo-wlz-1" ] || \
           [ "${HOSTNAME}" == "ap-east-1a" ] || \
           [ "${HOSTNAME}" == "azure" ] || \
           [ "${HOSTNAME}" == "gcp" ] || \
           [ "${HOSTNAME}" == "tencentcloud" ]; then
            curl -fsSL https://sing-box.app/install.sh | sh -s -- --version 1.15.0-alpha.9 >/dev/null 2>&1
        else
            echo "WARNING: The hostname must be one of the following:"
            echo "  - pikvm"
            echo "  - cmcc"
            echo "  - verizon"
            echo "  - at&t"
            echo "  - t-mobile"
            echo "  - aws"
            echo "  - us-west-1a"
            echo "  - us-west-2a"
            echo "  - us-west-2-wl1-sfo-wlz-1"
            echo "  - ap-east-1a"
            echo "  - azure"
            echo "  - gcp"
            echo "  - tencentcloud"
            exit 1
        fi

        if [ -d "/etc/sing-box" ]; then
            rm /etc/sing-box/config.json >/dev/null 2>&1
            rm /etc/sing-box/config.json.dpkg-new >/dev/null 2>&1
        fi
    fi
    exit 0
}

function install_golang_and_caddy_with_forwardproxy_at_naive() {
    apt-get install golang -y >/dev/null 2>&1
    go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest >/dev/null 2>&1
    /root/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@naive >/dev/null 2>&1
    mv ./caddy /usr/bin >/dev/null 2>&1
    rm -rf go >/dev/null 2>&1
    rm -rf /root/.cache/go-build >/dev/null 2>&1
    exit 0
}

function generate_naive() {
    if [ ! -f "/usr/bin/sing-box" ]; then
        echo "WARNING: The sing-box binary file isn't installed!"
        exit 1
    fi

    if [ ! -f "/usr/bin/caddy" ]; then
        echo "WARNING: The Caddy binary file isn't installed!"
        echo "NOTICE:"
        echo '  - Install Golang and the Caddy binary with "klzgrad/forwardproxy@naive" padding layer, combining both in one?'
        echo ""
        echo "      go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest"
        echo "      ~/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@naive"
        echo ""
        exit 1
    fi

    if [ ! -f "/etc/caddy/Caddyfile" ]; then
        echo "ERROR: No such a file!"
        echo "  - /etc/caddy/Caddyfile"
        exit 1
    fi

    if [ ! -d "/var/www/html/index.html" ]; then
        echo "ERROR: No such a file!"
        echo "  - /var/www/html/index.html"
        exit 1
    fi

    if [ ! -d "/etc/caddy" ]; then
        mkdir /etc/caddy
    fi

    wget -q https://raw.githubusercontent.com/sengshinlee/chromium-like4sing-tun2socks5/refs/heads/main/caddy/Caddyfile -P /etc/caddy
    chmod 600 /etc/caddy/Caddyfile

    if [ ! -d "/var/www/html" ]; then
        mkdir -p /var/www/html
    fi

    wget -q https://github.com/sengshinlee/chromium-like4sing-tun2socks5/archive/refs/heads/main.zip
    if [ ! -f "/usr/bin/unzip" ]; then
        apt-get install unzip -y >/dev/null 2>&1
    fi
    unzip main.zip >/dev/null 2>&1
    cp -r chromium-like4sing-tun2socks5-main/caddy/var/www/html /var/www/html >/dev/null 2>&1
    rm -rf main.zip chromium-like4sing-tun2socks5-main >/dev/null 2>&1

    if [ ! -d "/etc/sing-box" ]; then
        mkdir /etc/sing-box
    fi

    if [[ "${SERVER_PUBLIC_IP}" == *":"* ]]; then
        wget -q https://raw.githubusercontent.com/sengshinlee/chromium-like4sing-tun2socks5/refs/heads/main/user-custom-templates/server/ubuntu/sing-tun2socks5/config.ipv4.obfs.chromium-like.json5 -P /etc/sing-box
        wget -q https://raw.githubusercontent.com/sengshinlee/chromium-like4sing-tun2socks5/refs/heads/main/user-custom-templates/server/ubuntu/sing-tun2socks5/config.obfs.chromium-like.json5 -P /etc/sing-box

        echo "WARNING:"
        echo ""
        echo -e "  When you use \"config.ipv4.obfs.chromium-like.json5\", you must rename it to \"config.obfs.chromium-like.json5\"."
        echo ""
    else
        wget -q https://raw.githubusercontent.com/sengshinlee/chromium-like4sing-tun2socks5/refs/heads/main/user-custom-templates/server/ubuntu/sing-tun2socks5/config.ipv4.obfs.chromium-like.json5 -O /etc/sing-box/config.obfs.chromium-like.json5
    fi
    chmod 600 /etc/sing-box/*.json5
    exit 0
}

function chromium-like_up() {
    if [[ "${SERVER_PUBLIC_IP}" == *":"* ]]; then
        sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
        sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null 2>&1
        sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
        sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
    else
        sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
        sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
        sysctl -w net.ipv6.conf.lo.disable_ipv6=1 >/dev/null 2>&1
        sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
        sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
        sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
    fi
    ip -4 rule add iif "${SERVER_PUBLIC_NIC}" lookup 2022 priority 8990 >/dev/null 2>&1
    sing-box run -c /etc/sing-box/config.obfs.chromium-like.json5 &
    caddy run --config /etc/caddy/Caddyfile &
    exit 0
}

function chromium-like_down() {
    pkill -15 -f "caddy run --config /etc/caddy/Caddyfile" >/dev/null 2>&1
    ip -4 rule del iif "${SERVER_PUBLIC_NIC}" lookup 2022 priority 8990 >/dev/null 2>&1
    pkill -15 -f "sing-box run -c /etc/sing-box/config.obfs.chromium-like.json5" >/dev/null 2>&1
    if [[ "${SERVER_PUBLIC_IP}" == *":"* ]]; then
        sysctl -w net.ipv4.ip_forward=0 >/dev/null 2>&1
        sysctl -w net.ipv6.conf.all.forwarding=0 >/dev/null 2>&1
        sysctl -w net.core.default_qdisc=fq_codel >/dev/null 2>&1
        sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1
    else
        sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null 2>&1
        sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null 2>&1
        sysctl -w net.ipv6.conf.lo.disable_ipv6=0 >/dev/null 2>&1
        sysctl -w net.ipv4.ip_forward=0 >/dev/null 2>&1
        sysctl -w net.core.default_qdisc=fq_codel >/dev/null 2>&1
        sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1
    fi
    exit 0
}

function enable_ip_forwarding_and_google_bbr() {
    if [[ "${SERVER_PUBLIC_IP}" == *":"* ]]; then
        cat >/etc/sysctl.d/99-ip-forwarding-and-google-bbr.conf <<EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
    else
        cat >/etc/sysctl.d/99-ip-forwarding-and-google-bbr.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv4.ip_forward = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
    fi
    sysctl -p /etc/sysctl.d/99-ip-forwarding-and-google-bbr.conf >/dev/null 2>&1
    exit 0
}

function disable_ip_forwarding_and_google_bbr() {
    rm /etc/sysctl.d/99-ip-forwarding-and-google-bbr.conf >/dev/null 2>&1
    sysctl -p /etc/sysctl.conf* >/dev/null 2>&1
    exit 0
}

function remove() {
    if [ -f "/usr/bin/sing-box" ]; then
        rm /usr/local/bin/caddy-run-cron.sh >/dev/null 2>&1
        rm /var/log/caddy-run-cron.log >/dev/null 2>&1
        rm /usr/local/bin/sing-box-run-cron.sh >/dev/null 2>&1
        rm /var/log/sing-box-run-cron.log >/dev/null 2>&1
        rm -rf /root/.local/share/caddy >/dev/null 2>&1
        rm -rf /root/.config/caddy >/dev/null 2>&1
        rm /root/cache.db >/dev/null 2>&1
        rm /home/ubuntu/cache.db >/dev/null 2>&1

        pkill -15 -f "caddy run --config /etc/caddy/Caddyfile" >/dev/null 2>&1
        ip -4 rule del iif "${SERVER_PUBLIC_NIC}" lookup 2022 priority 8990 >/dev/null 2>&1
        pkill -15 -f "sing-box run -c /etc/sing-box/config.obfs.chromium-like.json5" >/dev/null 2>&1
        apt-get purge sing-box -y >/dev/null 2>&1

        if [ -d "/etc/sing-box" ]; then
            rm -rf /etc/sing-box >/dev/null 2>&1
        fi

        if [ -d "/etc/caddy" ]; then
            rm -rf /etc/caddy >/dev/null 2>&1
        fi

        if [ -d "/var/www/html" ]; then
            rm -rf /var/www >/dev/null 2>&1
        fi

        echo "NOTICE:"
        echo "  - Remove your cron schedule?"
        echo ""
        echo "      crontab -e"
        echo ""
    else
        echo "NOTICE: Not installed, no need to remove!"
    fi
    exit 0
}

function caddy_run_cron() {
    cat >/usr/local/bin/caddy-run-cron.sh <<'EOF'
#!/bin/bash

if [ $(ps aux | grep "caddy run --config /etc/caddy/Caddyfile" | wc -l) -eq 0 ]; then
    echo "$(date): Caddy is closed, reopening..." | sudo tee -a /var/log/caddy-run-cron.log
    sudo caddy run --config /etc/caddy/Caddyfile
fi
EOF

    chmod +x /usr/local/bin/caddy-run-cron.sh >/dev/null 2>&1

    echo "NOTICE:"
    echo "  - Add a new cron schedule?"
    echo ""
    echo '      (crontab -l 2>/dev/null; echo "* * * * * /usr/local/bin/caddy-run-cron.sh") | crontab -'
    echo ""
    echo "  - Edit it again?"
    echo ""
    echo "      crontab -e"
    echo ""
    exit 0
}

function sing_box_run_cron() {
    cat >/usr/local/bin/sing-box-run-cron.sh <<'EOF'
#!/bin/bash

if [ $(ps aux | grep "sing-box run -c /etc/sing-box/" | wc -l) -eq 1 ]; then
    echo "$(date): sing-box is closed, reopening..." | sudo tee -a /var/log/sing-box-run-cron.log
    sudo sing-box run -c /etc/sing-box/config.obfs.chromium-like.json5
fi
EOF

    chmod +x /usr/local/bin/sing-box-run-cron.sh >/dev/null 2>&1

    echo "NOTICE:"
    echo "  - Add a new cron schedule?"
    echo ""
    echo '      (crontab -l 2>/dev/null; echo "* * * * * /usr/local/bin/sing-box-run-cron.sh") | crontab -'
    echo ""
    echo "  - Edit it again?"
    echo ""
    echo "      crontab -e"
    echo ""
    exit 0
}

function help() {
    cat <<EOF
USAGE
    bash sing-box.sh [OPTION]

OPTION
    -h, --help              Show help manual
    -is, --install-sing-box Install "sing-box-1.15.0-alpha.9-linux"
    -ic, --install-caddy    Install Caddy with "klzgrad/forwardproxy@naive" padding layer
    -gn, --generate-naive   Generate 2 files: "config[.ipv4].obfs.chromium-like.json5"
    -u, --up                Run NaiveProxy service
    -d, --down              Stop NaiveProxy service
    -e, --enable            Enable IP forwarding and Google BBR
    -D, --disable           Disable IP forwarding and Google BBR, restore defaults
    -r, --remove            Uninstall sing-box, Caddy and remove all configuration files
    -ac, --add-caddy        Add a "caddy run --config /etc/caddy/Caddyfile" cron schedule
    -an, --add-naive        Add a "sing-box run -c /etc/sing-box/config.obfs.chromium-like.json5" cron schedule
EOF
    exit 0
}

function main() {
    distribution
    root

    if [ "$#" -eq 0 ]; then
        help
    fi

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h|--help)
                help
                ;;
            -is|--install-sing-box)
                install_sing-box
                ;;
            -ic|--install-caddy)
                install_golang_and_caddy_with_forwardproxy_at_naive
                ;;
            -gw|--generate-naive)
                generate_naive
                ;;
            -u|--up)
                chromium-like_up
                ;;
            -d|--down)
                chromium-like_down
                ;;
            -e|--enable)
                enable_ip_forwarding_and_google_bbr
                ;;
            -D|--disable)
                disable_ip_forwarding_and_google_bbr
                ;;
            -r|--remove)
                remove
                ;;
            -aw|--add-caddy)
                caddy_run_cron
                ;;
            -at|--add-naive)
                sing_box_run_cron
                ;;
            *)
                echo "ERROR: Invalid option \"$1\"!"
                exit 1
                ;;
        esac
        shift
    done
}

main "$@"
