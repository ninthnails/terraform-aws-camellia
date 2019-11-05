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
}

variable "public_zone_id" {
  type = string
}

variable "allowed_cidrs" {
  type = list(string)
  default = [
    "10.0.0.0/16"
  ]
}

variable "key_pair_name" {
}

variable "camellia_ami_id" {
  type = string
}

variable "kafka_instance_type" {
  default = "t3a.micro"
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

variable "manager_storage_type" {
  default = "t3a.medium"
}

variable "tags" {
  type = "map"
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
  key_name = var.key_pair_name
  cluster_size = 3
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
  zookeeper_connect = module.zookeeper.zookeeper_connect
  private_zone_ids = var.private_zone_ids
  instance_type = var.kafka_instance_type
  storage_type = var.kafka_storage_type
  storage_volume_type = var.kafka_storage_volume_type
  storage_volume_size = var.kafka_storage_volume_size
}

module "manager" {
  source = "./manager"
  prefix = var.prefix
  vpc_id = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  public_subnet_ids = var.public_subnet_ids
  key_pair_name = var.key_pair_name
  lb_allowed_cidrs = var.allowed_cidrs
  instance_type = var.manager_storage_type
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
output "zookeeper_connect" {
  value = module.zookeeper.zookeeper_connect
}

output "kafka_bootstrap_servers_private" {
  value = module.kafka.bootstrap_servers_private
}

output "manager_cruise_control_endpoint" {
  value = module.manager.public_cruise_control_endpoint
}

output "manager_kafka_manager_endpoint" {
  value = module.manager.public_kafka_manager_endpoint
}
