#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# ====== Cấu hình cơ bản ======
WORKDIR="/home/bkns"
WORKDATA="${WORKDIR}/data.txt"
FIRST_PORT=60001
LAST_PORT=62000

# ====== Hàm random chuỗi và IPv6 ======
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c16
    echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# ====== Cài 3proxy ======
install_3proxy() {
    if [ -f /usr/local/etc/3proxy/bin/3proxy ]; then
        echo "3proxy already installed, skipping build."
        return
    fi

    echo "Installing 3proxy..."
    URL="https://github.com/z3APA3A/3proxy/archive/refs/tags/0.8.13.tar.gz"
    wget -qO- $URL | tar -xzf-
    cd 3proxy-0.8.13
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd $WORKDIR
}

# ====== Sinh file cấu hình cho 3proxy ======
gen_3proxy() {
    cat <<EOF
daemon
maxconn 4000
nserver 1.1.1.1
nserver 8.8.4.4
nserver 2001:4860:4860::8888
nserver 2001:4860:4860::8844
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6291456
flush
auth strong

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})

$(awk -F "/" '{print "auth strong\nallow " $1 "\nproxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\nflush\n"}' ${WORKDATA})
EOF
}

# ====== Sinh dữ liệu proxy và IPv6 ======
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "user$port/$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

# ====== Sinh script thêm IPv6 vào interface ======
gen_ifconfig() {
    cat <<EOF
#!/bin/bash
$(awk -F "/" '{print "ip -6 addr add " $5 "/64 dev eth0"}' ${WORKDATA})
EOF
}

# ====== Sinh file proxy.txt cho người dùng ======
gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

# ====== Bắt đầu chạy ======
echo "Working folder: $WORKDIR"
mkdir -p $WORKDIR && cd $WORKDIR

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Detected IPv4: ${IP4}"
echo "Detected IPv6 prefix: ${IP6}"

install_3proxy

gen_data > $WORKDATA
gen_ifconfig > ${WORKDIR}/boot_ifconfig.sh
chmod +x ${WORKDIR}/boot_ifconfig.sh

gen_3proxy > /usr/local/etc/3proxy/3proxy.cfg

# ====== Ghi vào rc.local (chống trùng dòng cũ) ======
sed -i '/3proxy/d;/boot_ifconfig.sh/d;/ulimit -n 10048/d' /etc/rc.d/rc.local

cat >> /etc/rc.d/rc.local <<EOF
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

chmod +x /etc/rc.d/rc.local
systemctl enable rc-local
systemctl start rc-local

bash /etc/rc.d/rc.local

gen_proxy_file_for_user

rm -rf /root/3proxy-0.8.13
rm -rf /root/setup.sh

echo "✅ Proxy setup complete!"
echo "File proxy.txt saved at: ${WORKDIR}/proxy.txt"
