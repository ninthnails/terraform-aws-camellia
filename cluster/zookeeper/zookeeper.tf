#################
# Variables and Local Variables
#################
variable "vpc_id" {
}

variable "subnet_ids" {
  type = "list"
}

variable "prefix" {
  default = "camellia"
}

variable "ami_id" {
}

variable "key_name" {
}

variable "cluster_size" {
  description = "Number of nodes in the cluster"
  default = "1"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "follower_port" {
  default = 2888
}

variable "election_port" {
  default = 3888
}

variable "client_port" {
  default = 2181
}

variable "tags" {
  type = "map"
  default = {}
}

locals {
  zk_node_ids = range(1, var.cluster_size + 1)
  zk_server_format = "server.%[1]s=%[2]s:${var.follower_port}:${var.election_port}"
  zk_servers = formatlist(local.zk_server_format, local.zk_node_ids, aws_network_interface.zookeeper.*.private_ip)

  zk_connect_format = "%s:${var.client_port}"
  zk_connect = join(",", formatlist("%s:${var.client_port}", aws_network_interface.zookeeper.*.private_ip))
}

#################
# Data
#################
data "aws_vpc" "this" {
  id = var.vpc_id
}

data "aws_subnet" "selected" {
  count = length(var.subnet_ids)
  id = var.subnet_ids[count.index]
}

#################
# Security Groups
#################
resource "aws_security_group" "zookeeper" {
  name_prefix = "${var.prefix}-kafka-zookeeper-"
  vpc_id = var.vpc_id
  description = "Security group for Zookeeper node"
  tags = var.tags
}

resource "aws_security_group_rule" "all-egress" {
  from_port = 0
  protocol = "all"
  security_group_id = aws_security_group.zookeeper.id
  cidr_blocks = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
  to_port = 65535
  type = "egress"
}

resource "aws_security_group_rule" "ssh-ingress" {
  type = "ingress"
  security_group_id = aws_security_group.zookeeper.id
  cidr_blocks = [
    data.aws_vpc.this.cidr_block
  ]
  from_port = "22"
  to_port = "22"
  protocol = "tcp"
}

resource "aws_security_group_rule" "http-ingress" {
  type = "ingress"
  security_group_id = aws_security_group.zookeeper.id
  cidr_blocks = [
    data.aws_vpc.this.cidr_block
  ]
  from_port = "8080"
  to_port = "8080"
  protocol = "tcp"
}

resource "aws_security_group_rule" "follower-ingress" {
  type = "ingress"
  security_group_id = aws_security_group.zookeeper.id
  source_security_group_id = aws_security_group.zookeeper.id
  from_port = var.follower_port
  to_port = var.follower_port
  protocol = "tcp"
}

resource "aws_security_group_rule" "election-ingress" {
  type = "ingress"
  security_group_id = aws_security_group.zookeeper.id
  source_security_group_id = aws_security_group.zookeeper.id
  from_port = var.election_port
  to_port = var.election_port
  protocol = "tcp"
}

resource "aws_security_group_rule" "client-ingress" {
  type = "ingress"
  security_group_id = aws_security_group.zookeeper.id
  from_port = var.client_port
  to_port = var.client_port
  protocol = "tcp"
  cidr_blocks = [
    data.aws_vpc.this.cidr_block
  ]
}

#################
# Network Interfaces
#################
resource "aws_network_interface" "zookeeper" {
  depends_on = [
    "aws_security_group.zookeeper"
  ]
  count = var.cluster_size
  subnet_id = element(var.subnet_ids, count.index % length(var.subnet_ids))
  private_ips_count = 0
  security_groups = [
    aws_security_group.zookeeper.id
  ]
  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-zookeeper-${count.index + 1}-static"))
}

#################
# Launch Template, Auto Scaling Group
#################
data "template_file" "user_data" {
  count = var.cluster_size
  template = file("${path.module}/zookeeper-user-data.tpl")

  vars = {
    node_id = count.index + 1
    servers = join(",", local.zk_servers)
  }
}

resource "aws_launch_template" "node" {
  count = var.cluster_size
  depends_on = [
    "aws_network_interface.zookeeper"
  ]
  name_prefix = "${var.prefix}-kafka-zookeeper-${count.index}-"
  image_id = var.ami_id
  instance_type = var.instance_type
  key_name = var.key_name
  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination = false
    device_index = 0
    network_interface_id = aws_network_interface.zookeeper[count.index].id
  }
  user_data = base64encode(data.template_file.user_data[count.index].rendered)
  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-zookeeper-${count.index + 1}"))
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.prefix}-kafka-zookeeper-${count.index + 1}"
      Terraform = "true"
    }
  }
  lifecycle {
    ignore_changes = [
      "image_id",
      "instance_type",
      "network_interfaces[0]",
      "key_name",
      "user_data"
    ]
  }
}

resource "aws_autoscaling_group" "node" {
  count = var.cluster_size
  desired_capacity = 1
  health_check_grace_period = 60
  health_check_type = "EC2"
  launch_template {
    id = aws_launch_template.node[count.index].id
    version = aws_launch_template.node[count.index].latest_version
  }
  name_prefix = "${var.prefix}-kafka-zookeeper-${count.index + 1}-"
  max_size = 1
  min_size = 1
  availability_zones = [
    data.aws_subnet.selected[count.index % length(data.aws_subnet.selected)].availability_zone
  ]
}

#################
# Outputs
#################
output "zookeeper_connect" {
  value = local.zk_connect
}
