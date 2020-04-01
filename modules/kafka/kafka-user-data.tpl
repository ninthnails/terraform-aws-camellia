#!/bin/bash -e

/usr/bin/sed -i -r "s/^127.0.0.1(.*)$/127.0.0.1\1 $(/usr/bin/hostname)/" /etc/hosts

/bin/cat << EOF >> /opt/kafka/config/environment
STORAGE_TYPE=${storage_type}
STORAGE_SET_SIZE=${storage_set_size}
STORAGE_BASE_DIR=/var/kafka
EOF

LISTENERS="${broker_listener},${client_listener}"
ADVERTISED_LISTENERS="${broker_advertised_listener},${client_advertised_listener}"

/usr/bin/sed -r -i \
-e "s|^broker\.id=.*|broker.id=${broker_id}|gm" \
-e "s|^broker\.rack=.*|broker.rack=${broker_rack}|gm" \
-e "s|^zookeeper\.connect=.*|zookeeper.connect=${zookeeper}|gm" \
-e "s|^listeners=.*|listeners=$${LISTENERS}|gm" \
-e "s|^advertised\.listeners=.*|advertised.listeners=$${ADVERTISED_LISTENERS}|gm" \
-e "s|^listener\.security\.protocol\.map=.*|listener.security.protocol.map=${protocol_map}|gm" \
-e "s|^cruise\.control\.metrics\.reporter\.bootstrap\.servers=.*|cruise.control.metrics.reporter.bootstrap.servers=${bootstrap_servers}|gm" \
-e "s|^default\.replication\.factor=.*|default.replication.factor=${default_replication_factor}|gm" \
-e "s|^offsets\.topic\.replication\.factor=.*|offsets.topic.replication.factor=${default_replication_factor}|gm" \
-e "s|^transaction\.state\.log\.replication\.factor=.*|transaction.state.log.replication.factor=${default_replication_factor}|gm" \
-e "s|^min\.insync\.replicas=.*|min.insync.replicas=${min_insync_replicas}|gm" \
-e "s|^transaction\.state\.log\.min\.isr=.*|transaction.state.log.min.isr=${min_insync_replicas}|gm" \
/opt/kafka/config/server.properties

/usr/bin/systemctl enable kafka-storage.service
/usr/bin/systemctl enable kafka.service
/usr/bin/systemctl start kafka
