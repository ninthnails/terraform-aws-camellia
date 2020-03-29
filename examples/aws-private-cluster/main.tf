#################
# Variables and Local Variables
#################
variable "aws_region" {
  default = "us-east-1"
}

variable "ssh_key_name" {
}

variable "public_zone_id" {
}

variable "allowed_cidrs" {
  type = map(list(string))
}

variable "kafka_cluster_size" {
  default = 1
}

variable "zookeeper_cluster_size" {
  default = 1
}

variable "manager_admin_password" {
  default = ""
}

variable "manager_lb_acm_certificate_arn" {
  default = ""
}

#################
# Providers
#################
provider "aws" {
  region = var.aws_region
  version = "~> 2.45"
}

provider "null" {
  version = "~> 2.1"
}

provider "template" {
  version = "~> 2.1"
}

#################
# Data
#################
data "aws_vpc" "this" {
  filter {
    name = "tag:Name"
    values = [
      "application"
    ]
  }
  filter {
    name = "state"
    values = [
      "available"
    ]
  }
}

data "aws_subnet_ids" "private" {
  vpc_id = data.aws_vpc.this.id
  filter {
    name = "tag:Name"
    values = ["private"]
  }
}

data "aws_subnet_ids" "public" {
  vpc_id = data.aws_vpc.this.id
  filter {
    name = "tag:Name"
    values = ["public"]
  }
}

data "aws_ami" "camellia" {
  name_regex = "camellia-kafka-2.3.1-hvm-*"
  owners = ["self"]
  filter {
    name = "state"
    values = ["available"]
  }
  most_recent = true
}


#################
# Modules
#################
module "cluster" {
  source = "../../cluster"
  manager_admin_password = var.manager_admin_password

  // Example of no Load Balancer, internally accessible manager
   manager_lb_enabled = false

   // Example of self signed certificate for development purpose
//   manager_lb_enabled = true
//   manager_lb_acm_certificate_arn = var.manager_lb_acm_certificate_arn

  vpc_id = data.aws_vpc.this.id
  private_subnet_ids = data.aws_subnet_ids.private.ids
  public_subnet_ids = data.aws_subnet_ids.public.ids
  key_pair_name = var.ssh_key_name
  public_zone_id = var.public_zone_id
  allowed_cidrs = var.allowed_cidrs
  camellia_ami_id = data.aws_ami.camellia.id
  kafka_storage_type = "root"
  kafka_storage_volume_type = "standard"
  kafka_cluster_size = var.kafka_cluster_size
  zookeeper_cluster_size = var.zookeeper_cluster_size
}

#################
# Outputs
#################
output "zookeeper_kafka_connect" {
  value = module.cluster.zookeeper_kafka_connect
}

output "kafka_bootstrap_servers_private" {
  value = module.cluster.kafka_bootstrap_servers_private
}

output "manager_cruise_control_endpoint" {
  value = module.cluster.manager_cruise_control_endpoint
}

output "manager_cluster_manager_endpoint" {
  value = module.cluster.manager_cluster_manager_endpoint
}
