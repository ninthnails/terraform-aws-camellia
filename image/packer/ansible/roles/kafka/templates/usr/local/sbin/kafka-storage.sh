#!/usr/bin/env bash

STORAGE_TYPE=${STORAGE_TYPE-root}
STORAGE_SET_SIZE=${STORAGE_SET_SIZE-0}
STORAGE_BASE_DIR=${STORAGE_BASE_DIR-'{{ kafka_data_path }}'}
DATA_INDEX=0

if [[ ${STORAGE_TYPE} == ebs && ${STORAGE_SET_SIZE} -ge 1 ]]; then
  DEVICE_LETTERS=(f g h i j k l m n o p)

  for i in $(seq 0 $((STORAGE_SET_SIZE - 1))); do
    device="/dev/sd${DEVICE_LETTERS[${i}]}"
    target="${STORAGE_BASE_DIR}/data${DATA_INDEX}"
    logs="${target}/logs"

    until [[ -b ${device} || -d ${target} ]]; do sleep 1; done

    if [[ -b ${device} ]] && [[ ! -d ${target} ]]; then
      mkfs.xfs ${device}
      mkdir -p ${target}
      echo "${device}  ${target}  xfs  defaults,auto,nouser,noatime,largeio  0  0" >> /etc/fstab
      mount --target ${target}
      mkdir -p ${logs}
      chown '{{ kafka_user }}:{{ kafka_user }}' ${logs}
    fi
    DATA_INDEX=$(( DATA_INDEX + 1 ))
  done

elif [[ ${STORAGE_TYPE} == instance ]]; then
  DEVICE_LETTERS=(b c d e f g h i j k l m n o p q r s t u v w x y)

  for letter in ${DEVICE_LETTERS[@]}; do
    device="/dev/sd${letter}"
    target="${STORAGE_BASE_DIR}/data${DATA_INDEX}"
    logs="${target}/logs"

    if [[ -b ${device} ]] && [[ ! -d ${target} ]]; then
      mkfs.xfs ${device}
      mkdir -p ${target}
      echo "${device}  ${target}  xfs  defaults,auto,nouser,noatime,largeio  0  0" >> /etc/fstab
      mount --target ${target}
      mkdir -p ${logs}
      chown '{{ kafka_user }}:{{ kafka_user }}' ${logs}
    fi
    DATA_INDEX=$(( DATA_INDEX + 1 ))
  done

  for number in $(seq 0 26); do
    device="/dev/nvme${number}n1"
    target="${STORAGE_BASE_DIR}/data${DATA_INDEX}"
    logs="${target}/logs"

    if [[ -b ${device} ]] && [[ ! -d ${target} ]]; then
      mkfs.xfs ${device}
      mkdir -p ${target}
      echo "${device}  ${target}  xfs  defaults,auto,nouser,noatime,largeio  0  0" >> /etc/fstab
      mount --target ${target}
      mkdir -p ${logs}
      chown '{{ kafka_user }}:{{ kafka_user }}' ${logs}
    fi
    DATA_INDEX=$(( DATA_INDEX + 1 ))
  done
else
  target="${STORAGE_BASE_DIR}/data0"
  logs="${target}/logs"
  mkdir -p ${logs}
  chown '{{ kafka_user }}:{{ kafka_user }}' ${logs}
fi

LOG_DIRS=$(find ${STORAGE_BASE_DIR} -maxdepth 2 -type d -name logs -printf ',%p')

sed -r -i "s|^log\.dirs=.*|log.dirs=${LOG_DIRS:1}|gm" "{{ kafka_install_path }}/config/server.properties"
