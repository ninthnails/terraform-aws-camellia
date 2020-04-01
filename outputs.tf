output "zookeeper_kafka_connect" {
  value = module.kafka.zookeeper_kafka_connect
}

output "kafka_bootstrap_servers_private" {
  value = module.kafka.bootstrap_servers_private
}

output "manager_cruise_control_endpoint" {
  value = module.manager.cruise_control_endpoint
}

output "manager_cluster_manager_endpoint" {
  value = module.manager.cluster_manager_endpoint
}
