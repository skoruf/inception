FROM debian:bullseye
#mariaDB container
RUN ["apt-get", "update"]
RUN ["apt-get", "upgrade", "-y"]
#RUN ["apt", "install", "-y", "vim"]
RUN ["apt-get", "install", "-y", "mariadb-server"]
COPY ["./conf/50-server.cnf", "/etc/mysql/mariadb.conf.d/50-server.cnf"]
COPY ["./tools/db_user.sh", "/"]
RUN ["chmod", "777", "/db_user.sh"]
CMD ["/db_user.sh"]
