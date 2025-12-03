FROM debian:bullseye
#wordpress container
RUN ["apt-get", "update"]
RUN ["apt-get", "upgrade"]
RUN ["apt-get", "install", "-y", "wget"]
RUN ["apt-get", "install", "-y", "php7.3"]
RUN ["apt-get", "install", "-y", "php-fpm"]
RUN ["apt-get", "install", "-y", "php-mysql"]
RUN ["apt-get", "install", "-y", "mariadb-client"]
RUN ["wget", "https://de-at.wordpress.org/wordpress-6.7.4-de_AT.tar.gz", "-P", "/var/www"]
RUN ["tar", "-xzf", "/var/www/wordpress-6.7.4-de_AT.tar.gz", "-C", "/var/www"]
RUN ["rm", "/var/www/wordpress-6.7.4-de_AT.tar.gz"]
RUN ["chown", "-R", "root:root", "/var/www/wordpress"]

#https://de-at.wordpress.org/wordpress-6.7.4-de_AT.tar.gz
