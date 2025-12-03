#!/bin/bash
service mysql start;
mysql -e "CREATE DATABASE IF NOT EXISTS \`${SQL_DB}\`;"
mysql -e "GRANT ALL PRIVILEGES ON \`${SQL_DB}\`.* TO \`${SQL_USER}\`@'%' IDENTIFIED BY '${SQL_PW}';"
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY ${SQL_ROOT_PW}';"
mysql -e "FLUSH PRIVILEGES;"
mysqladmin -u root -p$SQL_ROOT_PW shutdown
exec mysqld_safe
