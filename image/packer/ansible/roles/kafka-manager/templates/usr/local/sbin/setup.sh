#!/bin/bash -e

/usr/bin/sed -i -r "s/^127.0.0.1(.*)$/127.0.0.1\1 $(/usr/bin/hostname)/" /etc/hosts

get_ssm_parameter() {
  /usr/bin/aws ssm --region "${AWS_REGION}" get-parameter --name "${1}" --query Parameter.Value --output text
}

get_sm_secret() {
  /usr/bin/aws --region "${AWS_REGION}" secretsmanager get-secret-value --secret-id "${1}" --query SecretString --output text
}

setup_cruise_control() {
  /usr/bin/sed -r -i \
    -e "s|^bootstrap\.servers=.*|bootstrap.servers=${KAFKA_BOOTSTRAP_SERVERS}|gm" \
    -e "s|^zookeeper\.connect=.*|zookeeper.connect=${KAFKA_ZOOKEEPER_CONNECT}|gm" \
    -e "s|^sample\.store\.topic\.replication\.factor=.*|sample.store.topic.replication.factor=${CRUISE_CONTROL_TOPIC_REPLICATION_FACTOR}|gm" \
    /opt/cruise-control/config/cruisecontrol.properties

    /bin/echo "${CRUISE_CONTROL_CAPACITY}" > /opt/cruise-control/config/capacity.json

    /bin/echo "${CLUSTER_ENVIRONMENT},${CLUSTER_NAME},${CRUISE_CONTROL_API_ENDPOINT}" > \
      /opt/cruise-control/cruise-control-ui/dist/static/config.csv

    if [ "${CRUISE_CONTROL_ENABLED}" == "true" ]; then
      /usr/bin/systemctl enable cruisecontrol.service
      /usr/bin/systemctl start cruisecontrol
    fi
}

add_kafka_manager_env() {
  /bin/echo "${1}='${2}'" >> /opt/kafka-manager/conf/environment
}

setup_kafka_manager() {
  /usr/bin/sed -r -i -e "s|^ZK_HOSTS=.*|ZK_HOSTS=${ZOOKEEPER_CONNECT}|gm" /opt/kafka-manager/conf/environment

  local km_pswd="${KAFKA_MANAGER_PASSWORD}"
  case "${km_pswd}" in
  parameter/*) km_pswd="$(get_ssm_parameter "${km_pswd/parameter\//}")" ;;
  secrets/*) km_pswd="$(get_sm_secret "${km_pswd/secrets\//}")" ;;
  esac

  add_kafka_manager_env KAFKA_MANAGER_AUTH_ENABLED "${KAFKA_MANAGER_AUTH_ENABLED}"
  add_kafka_manager_env KAFKA_MANAGER_USERNAME "${KAFKA_MANAGER_USERNAME}"
  add_kafka_manager_env KAFKA_MANAGER_PASSWORD "${km_pswd}"

  /usr/bin/systemctl enable kafkamanager.service
  /usr/bin/systemctl start kafkamanager
}

setup_cruise_control
setup_kafka_manager
