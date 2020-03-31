#################
# Variables
#################
variable "prefix" {
  default = "camellia"
}

variable "vpc_id" {
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_zone_ids" {
  type = list(string)
  default = []
}

variable "manager_lb_acm_certificate_arn" {
  default = ""
}

variable "manager_lb_enabled" {
  default = false
}

variable "public_zone_id" {
  type = string
  default = ""
}

variable "allowed_cidrs" {
  type = map(list(string))
  default = {
    ipv4 = [
      "10.0.0.0/16"
    ]
    ipv6 = []
  }
}

variable "key_pair_name" {
}

variable "camellia_ami_id" {
  type = string
}

variable "zookeeper_instance_type" {
  default = "t3a.nano"
}

variable "zookeeper_cluster_size" {
  default = 1
}

variable "kafka_instance_type" {
  default = "t3a.nano"
}

variable "kafka_storage_type" {
  default = "ebs"
}

variable "kafka_storage_volume_type" {
  default = "gp2"
}

variable "kafka_storage_volume_size" {
  default = 1
}

variable "manager_admin_password" {
  default = ""
}

variable "manager_instance_type" {
  default = "t3a.nano"
}

variable "kafka_cluster_size" {
  default = 1
}

variable "tags" {
  type = map(string)
  default = {}
}

#################
# Modules
#################
module "zookeeper" {
  source = "./zookeeper"
  prefix = var.prefix
  vpc_id = var.vpc_id
  subnet_ids = var.private_subnet_ids
  ami_id = var.camellia_ami_id
  key_pair_name = var.key_pair_name
  instance_type = var.zookeeper_instance_type
  cluster_size = var.zookeeper_cluster_size
  tags = var.tags
}

module "kafka" {
  source = "./kafka"
  prefix = var.prefix
  vpc_id = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  public_subnet_ids = var.public_subnet_ids
  key_pair_name = var.key_pair_name
  ami_id = var.camellia_ami_id
  cluster_size = var.kafka_cluster_size
  zookeeper_connect = module.zookeeper.zookeeper_connect
  private_zone_ids = var.private_zone_ids
  instance_type = var.kafka_instance_type
  storage_type = var.kafka_storage_type
  storage_volume_type = var.kafka_storage_volume_type
  storage_volume_size = var.kafka_storage_volume_size
}

module "manager" {
  source = "./manager"
  admin_password = var.manager_admin_password
  prefix = var.prefix
  vpc_id = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  public_subnet_ids = var.public_subnet_ids
  key_pair_name = var.key_pair_name
  allowed_cidrs = var.allowed_cidrs
  instance_type = var.manager_instance_type
  lb_acm_certificate_arn = var.manager_lb_acm_certificate_arn
  lb_enabled = var.manager_lb_enabled
  kafka_cluster_size = var.kafka_cluster_size
  kafka_bootstrap_servers = module.kafka.bootstrap_servers_private
  kafka_zookeeper_connect = module.kafka.zookeeper_kafka_connect
  zookeeper_connect = module.zookeeper.zookeeper_connect
  kafka_broker_ids = module.kafka.broker_ids
  kafka_network_throughput_KB = 62500
  kafka_storage_volume_size = var.kafka_storage_volume_size
  ami_id = var.camellia_ami_id
  public_zone_id = var.public_zone_id
}

#################
# Outputs
#################
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
