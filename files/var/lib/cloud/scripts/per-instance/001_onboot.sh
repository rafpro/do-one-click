#!/bin/bash

# Protect the droplet
ufw limit ssh
ufw allow https
ufw allow http
ufw --force enable

#Generate Mysql root password.
root_mysql_pass=$(openssl rand -hex 24)
directus_mysql_pass=$(openssl rand -hex 24)
debian_sys_maint_mysql_pass=$(openssl rand -hex 24)

# Save the passwords
cat > /root/.digitalocean_password <<EOM
root_mysql_pass="${root_mysql_pass}"
directus_mysql_pass="${directus_mysql_pass}"
EOM

mysqladmin -u root -h localhost password ${root_mysql_pass}

mysql -uroot -p${root_mysql_pass} \
      -e "ALTER USER 'debian-sys-maint'@'localhost' IDENTIFIED BY '${debian_sys_maint_mysql_pass}'"

mysql -uroot -p${root_mysql_pass} \
      -e "CREATE DATABASE directus"

mysql -uroot -p${root_mysql_pass} \
      -e "CREATE USER 'directus'@'localhost' IDENTIFIED BY '${directus_mysql_pass}'"

mysql -uroot -p${root_mysql_pass} \
      -e "GRANT ALL PRIVILEGES ON *.* TO 'directus'@'localhost'"

# Run mysql_secure_installation

MYSQL_ROOT_PASSWORD=${debian_sys_maint_mysql_pass}

SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"$MYSQL_ROOT_PASSWORD\r\"
expect \"Change the root password?\"
send \"n\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")

echo "$SECURE_MYSQL"

cat > /etc/mysql/debian.cnf <<EOM
# Automatically generated for Debian scripts. DO NOT TOUCH!
[client]
host     = localhost
user     = debian-sys-maint
password = ${debian_sys_maint_mysql_pass}
socket   = /var/run/mysqld/mysqld.sock
[mysql_upgrade]
host     = localhost
user     = debian-sys-maint
password = ${debian_sys_maint_mysql_pass}
socket   = /var/run/mysqld/mysqld.sock
EOM
