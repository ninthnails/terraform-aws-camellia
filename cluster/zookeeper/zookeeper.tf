#################
# Variables and Local Variables
#################
variable "vpc_id" {
}

variable "subnet_ids" {
  type = list(string)
}

variable "prefix" {
  default = "camellia"
}

variable "ami_id" {
}

variable "key_pair_name" {
}

variable "cluster_size" {
  description = "Number of nodes in the cluster"
  default = "1"
}

variable "instance_type" {
  default = "t3a.nano"
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
  type = map(string)
  default = {}
}

locals {
  instance_type_support_recovery = contains(
    ["a1", "c3", "c4", "c5", "c5n", "m3", "m4", "m5", "m5a", "m5n", "p3", "r3", "r4", "r5", "r5a", "r5n", "t2", "t3", "t3a", "x1", "x1e"],
    split(".", var.instance_type)[0]
  )

  zk_node_ids = range(1, var.cluster_size + 1)
  zk_server_format = "server.%[1]s=%[2]s:${var.follower_port}:${var.election_port}"
  zk_servers = formatlist(local.zk_server_format, local.zk_node_ids, aws_network_interface.zookeeper.*.private_ip)

  zk_connect_format = "%s:${var.client_port}"
  zk_connect = join(",", formatlist("%s:${var.client_port}", aws_network_interface.zookeeper.*.private_ip))
}

#################
# Data
#################
data "aws_region" "this" {
}

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
    aws_security_group.zookeeper
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
# EC2 Instances
#################
data "template_file" "user_data" {
  count = var.cluster_size
  template = file("${path.module}/zookeeper-user-data.tpl")

  vars = {
    node_id = count.index + 1
    servers = join(",", local.zk_servers)
  }
}

resource "aws_instance" "node" {
  count = var.cluster_size
  ami = var.ami_id
  instance_type = var.instance_type
  lifecycle {
    ignore_changes = all
  }
  network_interface {
    delete_on_termination = false
    device_index = 0
    network_interface_id = aws_network_interface.zookeeper[count.index].id
  }
  key_name = var.key_pair_name

  ebs_optimized = false
  credit_specification {
    cpu_credits = "standard"
  }

  user_data = data.template_file.user_data[count.index].rendered

  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-zookeeper-${count.index + 1}"))
}

#################
# Alarms
#################
resource "aws_cloudwatch_metric_alarm" "reboot" {
  count = local.instance_type_support_recovery ? length(aws_instance.node) : 0
  alarm_actions = [
    "arn:aws:automate:${data.aws_region.this.name}:ec2:reboot"
  ]
  alarm_description = "Reboot Linux instance when Instance status check failed for 5 minutes"
  alarm_name = "${var.prefix}-kafka-zookeeper-${count.index + 1}-reboot"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = 5
  evaluation_periods = 5
  threshold = 1
  metric_name = "StatusCheckFailed_Instance"
  namespace = "AWS/EC2"
  period = 60
  statistic = "Maximum"
  dimensions = {
    InstanceId = aws_instance.node[count.index].id
  }
  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-zookeeper-${count.index + 1}-reboot"))
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_metric_alarm" "recovery" {
  count = local.instance_type_support_recovery ? length(aws_instance.node) : 0
  alarm_actions = [
    "arn:aws:automate:${data.aws_region.this.name}:ec2:recover"
  ]
  alarm_description = "Recover Linux instance when System status check failed for 10 minutes"
  alarm_name = "${var.prefix}-kafka-zookeeper-${count.index + 1}-recovery"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = 10
  evaluation_periods = 10
  threshold = 1
  metric_name = "StatusCheckFailed_System"
  namespace = "AWS/EC2"
  period = 60
  statistic = "Maximum"
  dimensions = {
    InstanceId = aws_instance.node[count.index].id
  }
  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-zookeeper-${count.index + 1}-recovery"))
  lifecycle {
    create_before_destroy = true
  }
}

#################
# Outputs
#################
output "zookeeper_connect" {
  value = local.zk_connect
}
