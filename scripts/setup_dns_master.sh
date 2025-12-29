#!/bin/bash
# setup_dns_master.sh
# Automated Setup for BIND9 Master Server
# Author: [Your Name]

# 1. Variables
INTERFACE="ens160"  # CHANGE THIS to your actual interface name (e.g., eth0, ens33)
STATIC_IP="192.168.10.20/24"
GATEWAY="192.168.10.1"
TSIG_SECRET="iCU2EMsxp5QaufoPU8a8tm3/sFmKxe8FAWhRxsDChIQ=" # Matching your configs

echo "--- STARTING DNS MASTER SETUP ---"

# 2. Set Hostname
hostnamectl set-hostname ns1.example.local
echo "Hostname set to ns1.example.local"

# 3. Network Configuration (Optional - Uncomment if needed)
# echo "Configuring Network..."
# nmcli con mod "Wired connection 1" ipv4.addresses $STATIC_IP ipv4.gateway $GATEWAY ipv4.method manual
# nmcli con up "Wired connection 1"

# 4. Install Packages
echo "Installing BIND and Chrony..."
dnf install bind bind-utils chrony -y

# 5. Configure Firewall
echo "Configuring Firewall..."
firewall-cmd --permanent --add-service=dns
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload

# 6. Create Zone Files
echo "Creating Zone Files..."

# Forward Zone: example.local
cat <<EOF > /var/named/for.example.local.zone
\$TTL 86400
@   IN  SOA ns1.example.local. admin.example.local. (
        2025081601 ; serial
        3600       ; refresh
        1800       ; retry
        604800     ; expire
        86400 )
    IN  NS  ns1.example.local.
    IN  NS  ns2.example.local.
ns1     IN A 192.168.10.20
ns2     IN A 192.168.10.21
web01   IN A 192.168.10.30
site1   IN A 192.168.10.30
site2   IN A 192.168.10.30
site3   IN A 192.168.10.30
app1    IN A 192.168.10.31
app2    IN A 192.168.10.32
app3    IN A 192.168.10.33
EOF

# Forward Zone: corp.example.local (AD)
cat <<EOF > /var/named/for.corp.example.local.zone
\$TTL 86400
@   IN  SOA ns1.example.local. admin.example.local. (
        2025081601 ; serial
        3600       ; refresh
        1800       ; retry
        604800     ; expire
        86400 )
    IN  NS  ns1.example.local.
    IN  NS  ns2.example.local.
dc01            IN A 192.168.10.10
winclient       IN A 192.168.10.101
linuxclient     IN A 192.168.10.100
_ldap._tcp.dc._msdcs      IN SRV 0 100 389 dc01.corp.example.local.
_kerberos._tcp.dc._msdcs  IN SRV 0 100 88  dc01.corp.example.local.
_kerberos._udp.dc._msdcs  IN SRV 0 100 88  dc01.corp.example.local.
_kerberos._tcp            IN SRV 0 100 88  dc01.corp.example.local.
_ldap._tcp                IN SRV 0 100 389 dc01.corp.example.local.
EOF

# Reverse Zone
cat <<EOF > /var/named/reverse.zone
\$TTL 86400
@   IN  SOA ns1.example.local. admin.example.local. (
        2025081601 ; serial
        3600       ; refresh
        1800       ; retry
        604800     ; expire
        86400 )
    IN  NS  ns1.example.local.
    IN  NS  ns2.example.local.
10  IN PTR dc01.corp.example.local.
20  IN PTR ns1.example.local.
21  IN PTR ns2.example.local.
30  IN PTR web01.example.local.
101 IN PTR winclient.corp.example.local.
100 IN PTR linuxclient.corp.example.local.
31  IN PTR app1.example.local.
32  IN PTR app2.example.local.
33  IN PTR app3.example.local.
EOF

# 7. Configure named.conf
echo "Configuring named.conf..."
cat <<EOF > /etc/named.conf
options {
    listen-on port 53 { 127.0.0.1; 192.168.10.20; };
    directory   "/var/named";
    allow-query     { localhost; 192.168.10.0/24; };
    recursion yes;
    dnssec-validation no;
    pid-file "/run/named/named.pid";
    session-keyfile "/run/named/session.key";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

key "bindkey" {
        algorithm hmac-sha256;
        secret "${TSIG_SECRET}";
};

server 192.168.10.21 {
    keys { bindkey; };
};

zone "." IN {
    type hint;
    file "named.ca";
};

zone "example.local" IN {
    type master;
    file "for.example.local.zone";
    allow-update { none; };
    allow-transfer { key "bindkey"; };
    notify yes;
};

zone "corp.example.local" IN {
    type master;
    file "for.corp.example.local.zone";
    allow-update { none; };
    allow-transfer { key "bindkey"; };
    notify yes;
};

zone "10.168.192.in-addr.arpa" IN {
    type master;
    file "reverse.zone";
    allow-update { none; };
    allow-transfer { key "bindkey"; };
    notify yes;
};
EOF

# 8. Set Permissions & Start Service
echo "Setting permissions..."
chown named:named /var/named/*.zone
systemctl enable --now named
systemctl restart named

echo "--- SETUP COMPLETE. VERIFY WITH: systemctl status named ---"
