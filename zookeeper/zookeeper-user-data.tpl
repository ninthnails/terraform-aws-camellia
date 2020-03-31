#!/bin/bash -e

ZK_SERVERS="${servers}"

/usr/bin/sed -i -r "s/^127.0.0.1(.*)$/127.0.0.1\1 $(/usr/bin/hostname)/" /etc/hosts
/usr/bin/su zookeeper -c '/usr/bin/sed -i "s/server\.1=.*//" /opt/zookeeper/conf/config.properties'
/usr/bin/su zookeeper -c "/usr/bin/echo -e $${ZK_SERVERS//,/\\\\n} >> /opt/zookeeper/conf/config.properties"
/usr/bin/su zookeeper -c "/opt/zookeeper/bin/zkServer-initialize.sh --myid=${node_id} --force /opt/zookeeper/conf/config.properties"

/usr/bin/systemctl enable zookeeper.service
/usr/bin/systemctl start zookeeper
