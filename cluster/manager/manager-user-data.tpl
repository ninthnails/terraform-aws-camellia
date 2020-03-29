#!/bin/bash

export AWS_REGION='${region}'
export CLUSTER_ENVIRONMENT='${cluster_environment}'
export CLUSTER_NAME='${cluster_name}'
export CRUISE_CONTROL_API_ENDPOINT='${api_endpoint}'
export CRUISE_CONTROL_CAPACITY='${capacity}'
export CRUISE_CONTROL_ENABLED='${cruise_control_enabled}'
export CRUISE_CONTROL_TOPIC_REPLICATION_FACTOR='${topic_replication_factor}'
export CRUISE_CONTROL_PASSWORD='${cruise_control_password}'
export CRUISE_CONTROL_SSL_ENABLED='${cruise_control_ssl_enabled}'
export CRUISE_CONTROL_USERNAME='${cruise_control_username}'
export KAFKA_BOOTSTRAP_SERVERS='${kafka_bootstrap_servers}'
export KAFKA_MANAGER_AUTH_ENABLED='${admin_enabled}'
export KAFKA_MANAGER_PASSWORD='${admin_password}'
export KAFKA_MANAGER_USERNAME='${admin_username}'
export KAFKA_ZOOKEEPER_CONNECT='${kafka_zookeeper_connect}'
export ZOOKEEPER_CONNECT='${zookeeper_connect}'

/usr/local/sbin/setup.sh
