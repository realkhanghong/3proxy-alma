#!/bin/bash
YUM=$(which yum)

if [ "$YUM" ]; then
    echo "Cấu hình IPv6 kernel..."
    cat > /etc/sysctl.d/99-ipv6.conf <<EOF
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.all.disable_ipv6 = 0
EOF
    sysctl -p /etc/sysctl.d/99-ipv6.conf >/dev/null 2>&1

    # Lấy phần thứ 3 và 4 của IPv4 public
    PUBLIC_IP=$(curl -4 -s icanhazip.com)
    IPC=$(echo "$PUBLIC_IP" | cut -d"." -f3)
    IPD=$(echo "$PUBLIC_IP" | cut -d"." -f4)

    # Lấy tên card mạng đang hoạt động (ví dụ: eth0, ens160, enp1s0, ...)
    IFACE=$(nmcli -t -f DEVICE,STATE dev | grep ':connected' | cut -d: -f1)

    echo "Phát hiện card mạng: $IFACE"
    echo "Địa chỉ IPv4: $PUBLIC_IP"
    echo "Phần mạng IPv4 thứ 3: $IPC"
    echo "Phần mạng IPv4 thứ 4: $IPD"

    # Xác định prefix IPv6 theo logic cũ
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

    # Bật IPv6 và gán địa chỉ
    nmcli connection modify "$IFACE" ipv6.method manual \
        ipv6.addresses "$IPV6ADDR" \
        ipv6.gateway "$IPV6GW" \
        ipv6.ip6-privacy 0 \
        ipv6.autoconnect yes

    nmcli connection up "$IFACE" >/dev/null 2>&1

    echo "✅ Đã cấu hình IPv6 thành công!"
else
    echo "Không tìm thấy YUM (có thể không phải hệ RedHat/AlmaLinux)"
fi
