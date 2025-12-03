#!/bin/bash
set -e

# Start MariaDB service
service mysql start

# Wait for MySQL to be ready
until mysqladmin ping -h localhost --silent; do
    sleep 1
done

# Create database if it doesn't exist
mysql -e "CREATE DATABASE IF NOT EXISTS \`${SQL_DB}\`;"

# Create user and grant privileges (using CREATE USER IF NOT EXISTS for MariaDB compatibility)
mysql -e "CREATE USER IF NOT EXISTS \`${SQL_USER}\`@'%' IDENTIFIED BY '${SQL_PW}';"
mysql -e "GRANT ALL PRIVILEGES ON \`${SQL_DB}\`.* TO \`${SQL_USER}\`@'%';"

# Set root password (properly quoted)
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${SQL_ROOT_PW}';"

# Flush privileges
mysql -e "FLUSH PRIVILEGES;"

# Shutdown MariaDB gracefully (using root with new password)
mysqladmin -u root -p"${SQL_ROOT_PW}" shutdown || mysqladmin shutdown

# Start MariaDB in foreground as PID 1 (best practice for Docker)
exec mysqld_safe
