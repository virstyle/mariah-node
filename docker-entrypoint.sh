#!/bin/bash

set -e

# we set gcomm string with cluster_members via ENV by default
CLUSTER_ADDRESS="gcomm://$CLUSTER_MEMBERS?pc.wait_prim=no"

# we use dns service discovery to find other members when in service mode
# and set/override cluster_members provided by ENV
if [ -n "$DB_SERVICE_NAME" ]; then
  
  # we check, if we have to enable bootstrapping, if we are the only/first node live
  if [ `getent hosts tasks.$DB_SERVICE_NAME|wc -l` = 1 ] ;then 
    # bootstrapping gets enabled by empty gcomm string
    CLUSTER_ADDRESS="gcomm://"
  else
    # we fetch IPs of service members
    CLUSTER_MEMBERS=`getent hosts tasks.$DB_SERVICE_NAME|awk '{print $1}'|tr '\n' ','`
    # we set gcomm string with found service members
    CLUSTER_ADDRESS="gcomm://$CLUSTER_MEMBERS?pc.wait_prim=no"
  fi
fi


# we create a galera config
config_file="/etc/mysql/my.cnf"

cat <<EOF > $config_file
# Node specifics 
# MariaDB database server configuration file.
#
# You can copy this file to one of:
# - "/etc/mysql/my.cnf" to set global options,
# - "~/.my.cnf" to set user-specific options.
#
# One can use all long options that the program supports.
# Run program with --help to get a list of available options and with
# --print-defaults to see which it would actually understand and use.
#
# For explanations see
# http://dev.mysql.com/doc/mysql/en/server-system-variables.html

# This will be passed to all mysql clients
# It has been reported that passwords should be enclosed with ticks/quotes
# escpecially if they contain "#" chars...
# Remember to edit /etc/mysql/debian.cnf when changing the socket location.
[client]
port            = 3306
socket          = /var/run/mysqld/mysqld.sock

# Here is entries for some specific programs
# The following values assume you have at least 32M ram

# This was formally known as [safe_mysqld]. Both versions are currently parsed.
[mysqld_safe]
socket          = /var/run/mysqld/mysqld.sock
nice            = 0

[mysqld]
#
# * Basic Settings
#
user           = mysql
pid-file        = /var/run/mysqld/mysqld.pid
socket          = /var/run/mysqld/mysqld.sock
port            = 3306
basedir         = /usr
datadir         = /var/lib/mysql
tmpdir          = /tmp
lc_messages_dir = /usr/share/mysql
lc_messages     = en_US
skip-external-locking
#
# Instead of skip-networking the default is now to listen only on
# localhost which is more compatible and is not less secure.
#bind-address           = 127.0.0.1
#
# * Fine Tuning
#
max_connections         = 100
connect_timeout         = 5
wait_timeout            = 600
max_allowed_packet      = 16M
thread_cache_size       = 128
sort_buffer_size        = 4M
bulk_insert_buffer_size = 16M
tmp_table_size          = 32M
max_heap_table_size     = 32M
#
# * MyISAM
#
# This replaces the startup script and checks MyISAM tables if needed
# the first time they are touched. On error, make copy and try a repair.
myisam_recover_options = BACKUP
key_buffer_size         = 128M
#open-files-limit       = 2000
table_open_cache        = 400
myisam_sort_buffer_size = 512M
concurrent_insert       = 2
read_buffer_size        = 2M
read_rnd_buffer_size    = 1M
#
# * Query Cache Configuration
#
# Cache only tiny result sets, so we can fit more in the query cache.
query_cache_limit               = 0
query_cache_size                = 0
# for more write intensive setups, set to DEMAND or OFF
#query_cache_type               = DEMAND
#
# * Logging and Replication
#
# Both location gets rotated by the cronjob.
# Be aware that this log type is a performance killer.
# As of 5.1 you can enable the log at runtime!
#general_log_file        = /var/log/mysql/mysql.log
#general_log             = 1
#
# Error logging goes to syslog due to /etc/mysql/conf.d/mysqld_safe_syslog.cnf.
#
# we do want to know about network errors and such
#log_warnings           = 2
#
# Enable the slow query log to see queries with especially long duration
#slow_query_log[={0|1}]
slow_query_log_file     = /var/log/mysql/mariadb-slow.log
long_query_time = 10
#log_slow_rate_limit    = 1000
#log_slow_verbosity     = query_plan

#log-queries-not-using-indexes
#log_slow_admin_statements
#
# The following can be used as easy to replay backup logs or for replication.
# note: if you are setting up a replication slave, see README.Debian about
#       other settings you may need to change.
#server-id              = 1
#report_host            = master1
#auto_increment_increment = 2
#auto_increment_offset  = 1
#log_bin                        = /var/log/mysql/mariadb-bin
#log_bin_index          = /var/log/mysql/mariadb-bin.index
# not fab for performance, but safer
#sync_binlog            = 1
expire_logs_days        = 10
max_binlog_size         = 100M
# slaves
#relay_log              = /var/log/mysql/relay-bin
#relay_log_index        = /var/log/mysql/relay-bin.index
#relay_log_info_file    = /var/log/mysql/relay-bin.info
#log_slave_updates
#read_only
#
# If applications support it, this stricter sql_mode prevents some
# mistakes like inserting invalid dates etc.
#sql_mode               = NO_ENGINE_SUBSTITUTION,TRADITIONAL
#
# * InnoDB
#
# InnoDB is enabled by default with a 10MB datafile in /var/lib/mysql/.
# Read the manual for more InnoDB related options. There are many!
default_storage_engine  = InnoDB
# you can't just change log file size, requires special procedure
#innodb_log_file_size   = 50M
innodb_buffer_pool_size = 256M
innodb_log_buffer_size  = 8M
innodb_file_per_table   = 1
innodb_open_files       = 400
innodb_io_capacity      = 400
innodb_flush_method     = O_DIRECT
#
# * Security Features
#
# Read the manual, too, if you want chroot!
# chroot = /var/lib/mysql/
#
# For generating SSL certificates I recommend the OpenSSL GUI "tinyca".
#
# ssl-ca=/etc/mysql/cacert.pem
# ssl-cert=/etc/mysql/server-cert.pem
# ssl-key=/etc/mysql/server-key.pem
#
# * Galera-related settings
#
[galera]
# Mandatory settings
# next 3 params disabled for the moment, since they are not mandatory and get changed with each new instance.
# they also triggered problems when trying to persist data with a backup service, since also the config has to be 
# persisted, but HOSTNAME changes at container startup.
#wsrep-node-name = $HOSTNAME 
#wsrep-sst-receive-address = $HOSTNAME
#wsrep-node-incoming-address = $HOSTNAME
wsrep_on=ON
wsrep_cluster_name = "$CLUSTER_NAME" 
wsrep_cluster_address = $CLUSTER_ADDRESS
wsrep_provider = /usr/lib/galera/libgalera_smm.so 
wsrep_sst_auth = "$GALERA_USER:$GALERA_PASS" 
wsrep_sst_method = xtrabackup
binlog_format = row 
default_storage_engine = InnoDB 
innodb_doublewrite = 1 
innodb_autoinc-lock-mode = 2 
innodb_flush_log_at_trx_commit = 2 
#
# Allow server to accept connections on all interfaces.
#
#bind-address=0.0.0.0
#
# Optional setting
#wsrep_slave_threads=1
#innodb_flush_log_at_trx_commit=0
[mysqldump]
quick
quote-names
max_allowed_packet      = 16M
[mysql]
#no-auto-rehash # faster start of mysql but no tab completion
[isamchk]
key_buffer              = 16M
#
# * IMPORTANT: Additional settings that can override those from this file!
#   The files must end with '.cnf', otherwise they'll be ignored.
#


EOF
GRANT ALL PRIVILEGES on *.* to '$GALERA_USER'@'%' identified by '$GALERA_PASS' WITH GRANT OPTION;
FLUSH PRIVILEGES;
GRANT ALL PRIVILEGES on *.* to 'root'@'%' identified by 'password' WITH GRANT OPTION;
FLUSH PRIVILEGES;


