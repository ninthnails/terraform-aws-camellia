#################
# Modules
#################
module "zookeeper" {
  source = "./modules/zookeeper"
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
  source = "./modules/kafka"
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
  source = "./modules/manager"
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
