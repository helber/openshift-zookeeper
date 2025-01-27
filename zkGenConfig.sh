#!/usr/bin/env bash
# Copyright 2016 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ZK_USER=${ZK_USER:-"zookeeper"}
ZK_LOG_LEVEL=${ZK_LOG_LEVEL:-"INFO"}
ZK_DATA_DIR=${ZK_DATA_DIR:-"/var/lib/zookeeper/data"}
ZK_DATA_LOG_DIR=${ZK_DATA_LOG_DIR:-"/var/lib/zookeeper/log"}
ZK_LOG_DIR=${ZK_LOG_DIR:-"/var/log/zookeeper"}
ZK_CONF_DIR=${ZK_CONF_DIR:-"/opt/zookeeper/conf"}
ZK_CLIENT_PORT=${ZK_CLIENT_PORT:-2181}
ZK_SERVER_PORT=${ZK_SERVER_PORT:-2888}
ZK_ELECTION_PORT=${ZK_ELECTION_PORT:-3888}
ZK_TICK_TIME=${ZK_TICK_TIME:-2000}
ZK_INIT_LIMIT=${ZK_INIT_LIMIT:-10}
ZK_SYNC_LIMIT=${ZK_SYNC_LIMIT:-5}
ZK_HEAP_SIZE=${ZK_HEAP_SIZE:-2G}
ZK_MAX_CLIENT_CNXNS=${ZK_MAX_CLIENT_CNXNS:-60}
ZK_MIN_SESSION_TIMEOUT=${ZK_MIN_SESSION_TIMEOUT:- $((ZK_TICK_TIME*2))}
ZK_MAX_SESSION_TIMEOUT=${ZK_MAX_SESSION_TIMEOUT:- $((ZK_TICK_TIME*20))}
ZK_SNAP_RETAIN_COUNT=${ZK_SNAP_RETAIN_COUNT:-3}
ZK_PURGE_INTERVAL=${ZK_PURGE_INTERVAL:-0}
ID_FILE="$ZK_DATA_DIR/myid"
ZK_CONFIG_FILE="$ZK_CONF_DIR/zoo.cfg"
LOGGER_PROPS_FILE="$ZK_CONF_DIR/log4j.properties"
JAVA_ENV_FILE="$ZK_CONF_DIR/java.env"
HOST=`hostname -s`
DOMAIN=`hostname -d`

function print_servers() {
	 for (( i=1; i<=$ZK_REPLICAS; i++ ))
	do
		echo "server.$i=$NAME-$((i-1)).$DOMAIN:$ZK_SERVER_PORT:$ZK_ELECTION_PORT"
	done
}

function validate_env() {
    echo "Validating enviornment"
	if [ -z $ZK_REPLICAS ]; then
		echo "ZK_REPLICAS is a mandatory environment variable"
		exit 1
	fi
   
	if [[ $HOST =~ (.*)-([0-9]+)$ ]]; then
		NAME=${BASH_REMATCH[1]}
		ORD=${BASH_REMATCH[2]}
	else
		echo "Failed to extract ordinal from hostname $HOST"
		exit 1
	fi
	MY_ID=$((ORD+1))
	echo "ZK_REPLICAS=$ZK_REPLICAS"
    echo "MY_ID=$MY_ID"
    echo "ZK_LOG_LEVEL=$ZK_LOG_LEVEL"
    echo "ZK_DATA_DIR=$ZK_DATA_DIR"
    echo "ZK_DATA_LOG_DIR=$ZK_DATA_LOG_DIR"
    echo "ZK_LOG_DIR=$ZK_LOG_DIR"
    echo "ZK_CLIENT_PORT=$ZK_CLIENT_PORT"
    echo "ZK_SERVER_PORT=$ZK_SERVER_PORT"
    echo "ZK_ELECTION_PORT=$ZK_ELECTION_PORT"
    echo "ZK_TICK_TIME=$ZK_TICK_TIME"
    echo "ZK_INIT_LIMIT=$ZK_INIT_LIMIT"
    echo "ZK_SYNC_LIMIT=$ZK_SYNC_LIMIT"
    echo "ZK_MAX_CLIENT_CNXNS=$ZK_MAX_CLIENT_CNXNS"
    echo "ZK_MIN_SESSION_TIMEOUT=$ZK_MIN_SESSION_TIMEOUT"
    echo "ZK_MAX_SESSION_TIMEOUT=$ZK_MAX_SESSION_TIMEOUT"
    echo "ZK_HEAP_SIZE=$ZK_HEAP_SIZE"
    echo "ZK_SNAP_RETAIN_COUNT=$ZK_SNAP_RETAIN_COUNT"
    echo "ZK_PURGE_INTERVAL=$ZK_PURGE_INTERVAL"
    echo "ENSEMBLE"
    print_servers
    echo "Enviorment validation successful"
}

function create_config() {
	rm -f $ZK_CONFIG_FILE
    echo "Creating ZooKeeper configuration"
    echo "#This file was autogenerated by k8szk DO NOT EDIT" >> $ZK_CONFIG_FILE
	echo "clientPort=$ZK_CLIENT_PORT" >> $ZK_CONFIG_FILE
    echo "dataDir=$ZK_DATA_DIR" >> $ZK_CONFIG_FILE
    echo "dataLogDir=$ZK_DATA_LOG_DIR" >> $ZK_CONFIG_FILE
    echo "tickTime=$ZK_TICK_TIME" >> $ZK_CONFIG_FILE
    echo "initLimit=$ZK_INIT_LIMIT" >> $ZK_CONFIG_FILE
    echo "syncLimit=$ZK_SYNC_LIMIT" >> $ZK_CONFIG_FILE
    echo "maxClientCnxns=$ZK_MAX_CLIENT_CNXNS" >> $ZK_CONFIG_FILE
    echo "minSessionTimeout=$ZK_MIN_SESSION_TIMEOUT" >> $ZK_CONFIG_FILE
    echo "maxSessionTimeout=$ZK_MAX_SESSION_TIMEOUT" >> $ZK_CONFIG_FILE
    echo "autopurge.snapRetainCount=$ZK_SNAP_RETAIN_COUNT" >> $ZK_CONFIG_FILE
    echo "autopurge.purgeInteval=$ZK_PURGE_INTERVAL" >> $ZK_CONFIG_FILE
    
    if [ $ZK_REPLICAS -gt 1 ]; then 
    	print_servers >> $ZK_CONFIG_FILE
    fi
    echo "Wrote ZooKeeper configuration file to $ZK_CONFIG_FILE"
}

function create_data_dirs() {
	echo "Creating ZooKeeper data directories and setting permissions"
    if [ ! -d $ZK_DATA_DIR  ]; then
        mkdir -p $ZK_DATA_DIR 
        chown -R $ZK_USER:$ZK_USER $ZK_DATA_DIR
    fi
    
    if [ ! -d $ZK_DATA_LOG_DIR  ]; then
        mkdir -p $ZK_DATA_LOG_DIR 
        chown -R $ZK_USER:$ZK_USER $ZK_DATA_LOG_DIR
    fi
   
    if [ ! -d $ZK_LOG_DIR  ]; then
        mkdir -p $ZK_LOG_DIR 
        chown -R $ZK_USER:$ZK_USER $ZK_LOG_DIR
    fi
    if [ ! -f $ID_FILE ]; then
        echo $MY_ID >> $ID_FILE
    fi
    echo "Created ZooKeeper data directories and set permissions in $ZK_DATA_DIR"
}

function create_log_props () {
	rm -f $LOGGER_PROPS_FILE
    echo "Creating ZooKeeper log4j configuration"
	echo "zookeeper.root.logger=CONSOLE" >> $LOGGER_PROPS_FILE
	echo "zookeeper.console.threshold="$ZK_LOG_LEVEL >> $LOGGER_PROPS_FILE
	echo "log4j.rootLogger=\${zookeeper.root.logger}" >> $LOGGER_PROPS_FILE
	echo "log4j.appender.CONSOLE=org.apache.log4j.ConsoleAppender" >> $LOGGER_PROPS_FILE
	echo "log4j.appender.CONSOLE.Threshold=\${zookeeper.console.threshold}" >> $LOGGER_PROPS_FILE
	echo "log4j.appender.CONSOLE.layout=org.apache.log4j.PatternLayout" >> $LOGGER_PROPS_FILE
	echo "log4j.appender.CONSOLE.layout.ConversionPattern=%d{ISO8601} [myid:%X{myid}] - %-5p [%t:%C{1}@%L] - %m%n" >> $LOGGER_PROPS_FILE
	echo "Wrote log4j configuration to $LOGGER_PROPS_FILE"
}

function create_java_env() {
    rm -f $JAVA_ENV_FILE
    echo "Creating JVM configuration file"
    echo "ZOO_LOG_DIR=$ZK_LOG_DIR" >> $JAVA_ENV_FILE
    echo "JVMFLAGS=\"-Xmx$ZK_HEAP_SIZE -Xms$ZK_HEAP_SIZE\"" >> $JAVA_ENV_FILE
    echo "Wrote JVM configuration to $JAVA_ENV_FILE"
}

validate_env && create_config && create_log_props && create_data_dirs && create_java_env