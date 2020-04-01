variable "prefix" {
  default = "camellia"
  description = "Resources will be prefixed with this."
}

variable "vpc_id" {
  description = "ID of the VPC where to create the image."
}

variable "private_subnet_ids" {
  description = "ID of the private subnets in the VPC where resources will be created."
  type = list(string)
}

variable "public_subnet_ids" {
  description = "ID of the public subnets in the VPC where resources will be created."
  type = list(string)
}

variable "private_zone_ids" {
  default = []
  description = "ID of the Route 53 Zones where internally used domain names will created. The zones must be private, i.e. attached to your VPC."
  type = list(string)
}

variable "manager_lb_acm_certificate_arn" {
  default = ""
  description = "The ARN for the certificate in Certificate Manager to be used on the Application Load Balancer for the manager tools."
}

variable "manager_lb_enabled" {
  default = false
  description = "Whether to create an Application Load Balancer for the manager tools."
}

variable "public_zone_id" {
  default = ""
  description = "ID of the Route 53 Zones where public domain names will created."
  type = string
}

variable "allowed_cidrs" {
  default = {
    ipv4 = [
      "10.0.0.0/16"
    ]
    ipv6 = []
  }
  description = "List of CIDR ranges allowed to communicate with internal or restricted resources."
  type = map(list(string))
}

variable "key_pair_name" {
  description = "The name of the SSH key pair that will be assigned to EC2 instances."
}

variable "camellia_ami_id" {
  description = "The ID of the Camellia AMI (Amazon Machine Image) to use for creating the cluster."
  type = string
}

variable "zookeeper_instance_type" {
  default = "t3a.nano"
  description = "The type of EC2 instance to be used for the Apache Zookeeper EC2 instances."
}

variable "zookeeper_cluster_size" {
  default = 1
  description = "The number of node (instance) to be created for the Apache Zookeper cluster."
}

variable "kafka_instance_type" {
  default = "t3a.nano"
  description = "The type of EC2 instance to be used for the Apache Kafka EC2 instances."
}

variable "kafka_storage_type" {
  default = "ebs"
  description = "The type of storage used for the Apache Kafka EC2 instances. Valid values are: ebs, instance, root."
}

variable "kafka_storage_volume_type" {
  default = "gp2"
  description = "The type of EBS volume used for the Apache Kafka EC2 instances."
}

variable "kafka_storage_volume_size" {
  default = 1
  description = "The size in GiB for the EBS volume."
}

variable "manager_admin_password" {
  default = ""
  description = <<EOL
The reference to a SSM Parameter Store parameter or Secrets Manager secret for the password of the administrator user of the manager tools.
Support also clear text value for ease of development.
EOL
}

variable "manager_instance_type" {
  default = "t3a.nano"
  description = "The type of EC2 instance to be used for the EC2 instance of the manager tools."
}

variable "kafka_cluster_size" {
  default = 1
  description = "The number of broker (instance) to be created for the Apache Kafka cluster."
}

variable "tags" {
  default = {}
  description = "A mapping of tags to assign to all resources."
  type = map(string)
}
