#!/bin/bash -e

/usr/bin/sed -i -r "s/^127.0.0.1(.*)$/127.0.0.1\1 $(/usr/bin/hostname)/" /etc/hosts

get_ssm_parameter() {
  /usr/bin/aws ssm --region "${AWS_REGION}" get-parameter --name "${1}" --query Parameter.Value --output text
}

get_sm_secret() {
  /usr/bin/aws --region "${AWS_REGION}" secretsmanager get-secret-value --secret-id "${1}" --query SecretString --output text
}

get_secret() {
  case "${1}" in
  parameter/*) get_ssm_parameter "${1/parameter\//}" ;;
  secrets/*) get_sm_secret "${1/secrets\//}" ;;
  *) echo "${1}"
  esac
}

setup_cruise_control() {
  local storepass

#  storepass=$(< /dev/urandom tr -dc '_A-Za-z0-9@%*~,.?' | head -c16)
  storepass=$(/bin/date | /bin/sha256sum | /bin/base64 | /bin/head -c 16)

  /bin/keytool -genkeypair -alias localhost -keyalg RSA -keysize 2048 -storetype PKCS12 -storepass "${storepass}" \
    -dname "CN=$(/usr/bin/hostname)" -validity 732 -keystore "{{ cruise_control_install_path }}/config/default.p12"

  /bin/chown "{{ cruise_control_user }}:{{ cruise_control_user }}" "{{ cruise_control_install_path }}/config/default.p12"
  /bin/chmod 0600 "{{ cruise_control_install_path }}/config/default.p12"

  /usr/bin/sed -r -i \
    -e "s|^bootstrap\.servers=.*|bootstrap.servers=${KAFKA_BOOTSTRAP_SERVERS}|gm" \
    -e "s|^zookeeper\.connect=.*|zookeeper.connect=${KAFKA_ZOOKEEPER_CONNECT}|gm" \
    -e "s|^sample\.store\.topic\.replication\.factor=.*|sample.store.topic.replication.factor=${CRUISE_CONTROL_TOPIC_REPLICATION_FACTOR}|gm" \
    -e "s|^webserver\.security\.enable=.*|webserver.security.enable=true|g" \
    -e "s|^webserver\.ssl\.enable=.*|webserver.ssl.enable=${CRUISE_CONTROL_SSL_ENABLED}|gm" \
    -e "s|^webserver\.ssl\.keystore\.password=.*|webserver.ssl.keystore.password=${storepass}|gm" \
    "{{ cruise_control_install_path }}/config/cruisecontrol.properties"

  /usr/bin/sed -r -i \
    -e "s|^admin:.*,ADMIN|${CRUISE_CONTROL_USERNAME}: $(get_secret "${CRUISE_CONTROL_PASSWORD}"),ADMIN|g" \
    "{{ cruise_control_install_path }}/config/realm.properties"

  /bin/echo "${CRUISE_CONTROL_CAPACITY}" > "{{ cruise_control_install_path }}/config/capacity.json"

  /bin/echo "${CLUSTER_ENVIRONMENT},${CLUSTER_NAME},${CRUISE_CONTROL_API_ENDPOINT}" > \
    "{{ cruise_control_install_path }}/cruise-control-ui/dist/static/config.csv"

  if [ "${CRUISE_CONTROL_ENABLED}" == "true" ]; then
    /usr/bin/systemctl enable cruisecontrol.service
    /usr/bin/systemctl start cruisecontrol
  fi
}

add_cluster_manager_env() {
  /bin/echo "${1}='${2}'" >> "{{ cmak_install_path }}/conf/environment"
}

setup_cluster_manager() {
  /usr/bin/sed -r -i -e "s|^ZK_HOSTS=.*|ZK_HOSTS=${ZOOKEEPER_CONNECT}|gm" "{{ cmak_install_path }}/conf/environment"

  add_cluster_manager_env KAFKA_MANAGER_AUTH_ENABLED "${KAFKA_MANAGER_AUTH_ENABLED}"
  add_cluster_manager_env KAFKA_MANAGER_USERNAME "${KAFKA_MANAGER_USERNAME}"
  add_cluster_manager_env KAFKA_MANAGER_PASSWORD "$(get_secret "${KAFKA_MANAGER_PASSWORD}")"

  /usr/bin/systemctl enable cmak.service
  /usr/bin/systemctl start cmak
}

setup_cruise_control
setup_cluster_manager
