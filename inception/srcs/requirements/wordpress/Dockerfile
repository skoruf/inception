FROM debian:bullseye
#wordpress container
RUN ["apt-get", "update"]
RUN ["apt-get", "upgrade", "-y"]
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

# Ensure runtime directories exist for php-fpm
RUN ["mkdir", "-p", "/run/php"]

# Copy php-fpm pool configuration to listen on 0.0.0.0:9000
COPY ["./conf/www.conf", "/etc/php/7.3/fpm/pool.d/www.conf"]

# Copy WordPress configuration (will use environment variables)
COPY ["./conf/wp-config.php", "/var/www/wordpress/wp-config.php"]

# Set proper permissions for WordPress directory
RUN ["chown", "-R", "www-data:www-data", "/var/www/wordpress"]

# Run php-fpm in the foreground so it becomes PID 1
CMD ["php-fpm7.3", "-F"]
