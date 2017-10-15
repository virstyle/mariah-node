FROM mariadb:10.2
MAINTAINER wangzhihui@outlook.com

RUN set -x \
    && apt-get update \
	&& apt-get install -y vim \
    && rm -rf /tmp/* /var/cache/apk/* /var/lib/apt/lists/*   

# we need to touch and chown config files, since we cant write as mysql user
RUN touch /etc/mysql/my.cnf \
    && chown mysql.mysql /etc/mysql/my.cnf 

# we expose all Cluster related Ports
# 3306: default MySQL/MariaDB listening port
# 4444: for State Snapshot Transfers
# 4567: Galera Cluster Replication
# 4568: Incremental State Transfer
EXPOSE 3306 4444 4567 4567/udp 4568

# we set some defaults
ENV GALERA_USER=galera \
    GALERA_PASS=galerapass \
    CLUSTER_NAME=dbcluster \
    MYSQL_ROOT_PASSWORD=password
#COPY *.sh   /usr/local/bin/
COPY docker-entrypoint.sh /
#ENTRYPOINT ["/docker-entrypoint.sh"] 
CMD ["mysqld"]

