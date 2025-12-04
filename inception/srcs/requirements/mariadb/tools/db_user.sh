#!/bin/bash
set -e

# Start MariaDB service (service name is mariadb on Debian)
if [ -x /etc/init.d/mariadb ]; then
    service mariadb start
else
    service mysql start
fi

# Wait for MySQL to be ready
until mysqladmin --protocol=socket --user=root --skip-password ping --silent >/dev/null 2>&1 || mysqladmin --protocol=socket --user=root --password="${SQL_ROOT_PW}" ping --silent >/dev/null 2>&1; do
    sleep 1
done

SOCKET_ARGS_NO_PW=(--protocol=socket --user=root --skip-password)
SOCKET_ARGS_WITH_PW=(--protocol=socket --user=root --password="${SQL_ROOT_PW}")

MYSQL_CMD=("${SOCKET_ARGS_WITH_PW[@]}")
PASSWORD_ALREADY_SET=0

if ! mysql "${MYSQL_CMD[@]}" -e "SELECT 1;" >/dev/null 2>&1; then
    MYSQL_CMD=("${SOCKET_ARGS_NO_PW[@]}")
else
    PASSWORD_ALREADY_SET=1
fi

# Create database if it doesn't exist
mysql "${MYSQL_CMD[@]}" -e "CREATE DATABASE IF NOT EXISTS \`${SQL_DB}\`;"

# Create user and grant privileges (using CREATE USER IF NOT EXISTS for MariaDB compatibility)
mysql "${MYSQL_CMD[@]}" -e "CREATE USER IF NOT EXISTS \`${SQL_USER}\`@'%' IDENTIFIED BY '${SQL_PW}';"
mysql "${MYSQL_CMD[@]}" -e "GRANT ALL PRIVILEGES ON \`${SQL_DB}\`.* TO \`${SQL_USER}\`@'%';"

# Set root password if needed, then switch to password auth
if [ $PASSWORD_ALREADY_SET -eq 0 ]; then
    mysql "${MYSQL_CMD[@]}" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${SQL_ROOT_PW}';"
    MYSQL_CMD=("${SOCKET_ARGS_WITH_PW[@]}")
fi

# Flush privileges
mysql "${MYSQL_CMD[@]}" -e "FLUSH PRIVILEGES;"

# Shutdown MariaDB gracefully (using root with password)
mysqladmin "${SOCKET_ARGS_WITH_PW[@]}" shutdown || mysqladmin shutdown

# Start MariaDB in foreground as PID 1 (best practice for Docker)
exec mysqld_safe
