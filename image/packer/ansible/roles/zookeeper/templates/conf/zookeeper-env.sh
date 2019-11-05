ZOOCFGDIR={{ zookeeper_install_path }}/conf
ZOOCFG=config.properties
ZOO_LOG_DIR={{ zookeeper_logging_path }}
ZOO_LOG4J_PROP="INFO,ROLLINGFILE"
ZK_SERVER_HEAP=128
SERVER_JVMFLAGS="-Xms${ZK_SERVER_HEAP}m \
-Dlog4j.configuration=file:{{ zookeeper_install_path }}/conf/log4j.properties \
-XX:ErrorFile={{ zookeeper_logging_path }}/hs_err_pid%p.log \
-XX:+HeapDumpOnOutOfMemoryError \
-XX:HeapDumpPath={{ zookeeper_logging_path }}/"
