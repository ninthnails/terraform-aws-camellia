output "zookeeper_kafka_connect" {
  description = "The endpoint to Apache Zookeeper where Apache Kafka store it's state."
  value = module.kafka.zookeeper_kafka_connect
}

output "kafka_bootstrap_servers_private" {
  description = "The endpoint for bootstrapping connection to Apache Kafka cluster from within the cluster."
  value = module.kafka.bootstrap_servers_private
}

output "manager_cruise_control_endpoint" {
  description = "The URL to the LinkedIn Cruise Control console."
  value = module.manager.cruise_control_endpoint
}

output "manager_cluster_manager_endpoint" {
  description = "The URL to the Yahoo CMAK (Cluster Manager for Apache Kafka) console."
  value = module.manager.cluster_manager_endpoint
}
