#!/bin/bash
YUM=$(which yum)

if [ "$YUM" ]; then
    echo "Cấu hình IPv6 kernel..."
    cat > /etc/sysctl.d/99-ipv6.conf <<EOF
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.all.disable_ipv6 = 0
EOF
    sysctl -p /etc/sysctl.d/99-ipv6.conf >/dev/null 2>&1

    PUBLIC_IP=$(curl -4 -s icanhazip.com)
    IPC=$(echo "$PUBLIC_IP" | cut -d"." -f3)
    IPD=$(echo "$PUBLIC_IP" | cut -d"." -f4)

    # 🔧 Chỉ lấy interface đang active, bỏ loopback
    IFACE=$(nmcli -t -f DEVICE,STATE dev | grep ':connected' | cut -d: -f1 | grep -v '^lo' | head -n1)

    if [ -z "$IFACE" ]; then
        echo "❌ Không tìm thấy card mạng đang hoạt động! Thoát..."
        exit 1
    fi

    echo "Phát hiện card mạng: $IFACE"
    echo "Địa chỉ IPv4: $PUBLIC_IP"
    echo "Phần mạng IPv4 thứ 3: $IPC"
    echo "Phần mạng IPv4 thứ 4: $IPD"

    # Xác định prefix IPv6
    if [ "$IPC" == "4" ]; then
        PREFIX="2403:6a40:0:40"
    elif [ "$IPC" == "5" ]; then
        PREFIX="2403:6a40:0:41"
    elif [ "$IPC" == "244" ]; then
        PREFIX="2403:6a40:2000:244"
    else
        PREFIX="2403:6a40:0:$IPC"
    fi

    IPV6ADDR="${PREFIX}::${IPD}:0000/64"
    IPV6GW="${PREFIX}::1"

    echo "Áp dụng IPv6 $IPV6ADDR (Gateway $IPV6GW)..."

    nmcli connection modify "$IFACE" ipv6.method manual \
        ipv6.addresses "$IPV6ADDR" \
        ipv6.gateway "$IPV6GW" \
        ipv6.ip6-privacy 0 \
        ipv6.autoconnect yes

    nmcli connection up "$IFACE" >/dev/null 2>&1

    # ✅ Kiểm tra IPv6 hoạt động
    echo "Kiểm tra kết nối IPv6..."
    if ping6 -c 2 ipv6.google.com >/dev/null 2>&1; then
        echo "✅ Đã cấu hình IPv6 thành công và kết nối hoạt động!"
    else
        echo "⚠️ IPv6 đã gán nhưng chưa ping được ra ngoài."
        echo "→ Kiểm tra firewall hoặc default gateway IPv6."
    fi

else
    echo "Không tìm thấy YUM (có thể không phải hệ RedHat/AlmaLinux)"
fi
