#!/bin/bash -e

/usr/bin/sed -i -r "s/^127.0.0.1(.*)$/127.0.0.1\1 $(/usr/bin/hostname)/" /etc/hosts

/usr/bin/sed -r -i \
-e "s|^bootstrap\.servers=.*|bootstrap.servers=${kafka_bootstrap_servers}|gm" \
-e "s|^zookeeper\.connect=.*|zookeeper.connect=${kafka_zookeeper_connect}|gm" \
/opt/cruise-control/config/cruisecontrol.properties

/bin/echo '${capacity}' > /opt/cruise-control/config/capacity.json

/bin/echo 'lab,${cluster_name},${api_endpoint}' > /opt/cruise-control/cruise-control-ui/static/config.csv

/usr/bin/systemctl enable cruisecontrol.service
/usr/bin/systemctl start cruisecontrol

/usr/bin/sed -r -i \
-e "s|^ZK_HOSTS=.*|ZK_HOSTS=${zookeeper_connect}|gm" \
/opt/kafka-manager/conf/environment

/usr/bin/systemctl enable kafkamanager.service
/usr/bin/systemctl start kafkamanager