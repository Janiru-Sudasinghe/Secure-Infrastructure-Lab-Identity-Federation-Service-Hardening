#!/bin/bash
# setup_web.sh
# Automated Setup for Apache Web Server (Virtual Hosts & SSL)
# Author: [Your Name]

echo "--- STARTING WEB SERVER SETUP ---"

# 1. Set Hostname
hostnamectl set-hostname web01.example.local

# 2. Install Packages
echo "Installing Apache, SSL, and Chrony..."
dnf install httpd mod_ssl openssl chrony -y

# 3. Configure Firewall
echo "Configuring Firewall..."
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload

# 4. Create Directory Structure
echo "Creating Web Directories..."
mkdir -p /var/www/vhosts/{site1,site2,site3,app1,app2,app3}

# 5. Create Sample Content
echo "Creating index.html files..."
echo "<h1>Welcome to SITE 1 (Name-Based)</h1>" > /var/www/vhosts/site1/index.html
echo "<h1>Welcome to SITE 2 (Name-Based)</h1>" > /var/www/vhosts/site2/index.html
echo "<h1>Welcome to SITE 3 (Name-Based)</h1>" > /var/www/vhosts/site3/index.html
echo "<h1>Welcome to APP 1 (IP-Based .31)</h1>" > /var/www/vhosts/app1/index.html
echo "<h1>Welcome to APP 2 (IP-Based .32)</h1>" > /var/www/vhosts/app2/index.html
echo "<h1>Welcome to APP 3 (Secure .33)</h1>" > /var/www/vhosts/app3/index.html

# 6. Set Permissions (SELinux)
echo "Setting Permissions..."
chown -R apache:apache /var/www/vhosts
restorecon -Rv /var/www/vhosts

# 7. Generate Self-Signed SSL for App3
echo "Generating SSL Certificate for App3..."
mkdir -p /etc/ssl/private /etc/ssl/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/app3.key \
  -out /etc/ssl/certs/app3.crt \
  -subj "/C=LK/ST=Western/L=Colombo/O=IT/CN=app3.example.local"

chmod 600 /etc/ssl/private/app3.key

# 8. Configure Virtual Hosts
echo "Writing vhost.conf..."
cat <<EOF > /etc/httpd/conf.d/vhost.conf
# Name-Based VHosts (192.168.10.30)
<VirtualHost 192.168.10.30:80>
    ServerName site1.example.local
    DocumentRoot "/var/www/vhosts/site1"
    ErrorLog "logs/site1-error.log"
</VirtualHost>
<VirtualHost 192.168.10.30:80>
    ServerName site2.example.local
    DocumentRoot "/var/www/vhosts/site2"
</VirtualHost>
<VirtualHost 192.168.10.30:80>
    ServerName site3.example.local
    DocumentRoot "/var/www/vhosts/site3"
</VirtualHost>

# IP-Based VHosts
<VirtualHost 192.168.10.31:80>
    ServerName app1.example.local
    DocumentRoot "/var/www/vhosts/app1"
</VirtualHost>
<VirtualHost 192.168.10.32:80>
    ServerName app2.example.local
    DocumentRoot "/var/www/vhosts/app2"
</VirtualHost>

# SSL VHost
<VirtualHost 192.168.10.33:443>
    ServerName app3.example.local
    DocumentRoot "/var/www/vhosts/app3"
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/app3.crt
    SSLCertificateKeyFile /etc/ssl/private/app3.key
</VirtualHost>

<Directory "/var/www/vhosts">
    AllowOverride None
    Require all granted
</Directory>
EOF

# 9. Start Apache
echo "Starting HTTPD..."
systemctl enable --now httpd
systemctl restart httpd

echo "--- WEB SETUP COMPLETE ---"
