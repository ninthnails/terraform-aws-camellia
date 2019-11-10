#################
# Variables
#################
variable "vpc_id" {
}

variable "private_subnet_ids" {
  type = "list"
}

variable "public_subnet_ids" {
  type = "list"
}

variable "ami_id" {
}

variable "key_pair_name" {
}

variable "kms_key_id" {
  default = "alias/aws/ebs"
}

variable "prefix" {
  default = "camellia"
}

variable "cluster_size" {
  default = 3
}

variable "instance_type" {
  default = "t3a.nano"
}

variable "broker_port" {
  default = 9091
}

variable "plaintext_port" {
  default = 9092
}

variable "tls_port" {
  default = 9093
}

variable "storage_type" {
  default = "root"
}

variable "storage_volume_type" {
  default = "gp2"
}

variable "storage_volume_size" {
  default = 1
}

variable "zookeeper_connect" {
}

variable "private_zone_ids" {
  type = list(string)
}

variable "tags" {
  type = "map"
  default = {}
}

#################
# Data and Local Variables
#################
data "aws_region" "current" {}

data "aws_vpc" "this" {
  id = var.vpc_id
}

data "aws_subnet" "private" {
  count = length(var.private_subnet_ids)
  id = var.private_subnet_ids[count.index]
}

data "null_data_source" "broker-ids" {
  count = var.cluster_size
  inputs = {
    id = count.index + 1
  }
}

data "aws_kms_key" "provided" {
  key_id = var.kms_key_id
}

locals {
  instance_type_support_recovery = contains(
    ["a1", "c3", "c4", "c5", "c5n", "m3", "m4", "m5", "m5a", "m5n", "p3", "r3", "r4", "r5", "r5a", "r5n", "t2", "t3", "t3a", "x1", "x1e"],
    split(".", var.instance_type)[0]
  )
  storage_ebs_flag = var.storage_type == "ebs" ? 1 : 0
  storage_instance_flag = var.storage_type == "instance" ? 1 : 0
  zookeeper_connect = "${var.zookeeper_connect}/kafka"
  broker_ids = range(1, var.cluster_size + 1)
}

#################
# Security Groups
#################
resource "aws_security_group" "private" {
  name_prefix = "${var.prefix}-kafka-private-"
  vpc_id = var.vpc_id
  description = "Control access to Kafka brokers from private subnets"
  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-private"))
}

resource "aws_security_group_rule" "private-egress-all" {
  from_port = 0
  protocol = "all"
  security_group_id = aws_security_group.private.id
  cidr_blocks = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
  to_port = 65535
  type = "egress"
}

resource "aws_security_group_rule" "private-ingress-ssh" {
  type = "ingress"
  security_group_id = aws_security_group.private.id
  cidr_blocks = [
    data.aws_vpc.this.cidr_block
  ]
  from_port = "22"
  to_port = "22"
  protocol = "tcp"
}

resource "aws_security_group_rule" "private-ingress-broker" {
  description = "Inter-broker TCP"
  type = "ingress"
  security_group_id = aws_security_group.private.id
  from_port = var.broker_port
  to_port = var.broker_port
  protocol = "tcp"
  source_security_group_id = aws_security_group.private.id
}

resource "aws_security_group_rule" "private-ingress-plaintext" {
  description = "Plaintext TCP"
  type = "ingress"
  security_group_id = aws_security_group.private.id
  from_port = var.plaintext_port
  to_port = var.plaintext_port
  protocol = "tcp"
  cidr_blocks = data.aws_subnet.private.*.cidr_block
}

resource "aws_security_group_rule" "private-ingress-tls" {
  description = "SSL/TLS TCP"
  type = "ingress"
  security_group_id = aws_security_group.private.id
  from_port = var.tls_port
  to_port = var.tls_port
  protocol = "tcp"
  cidr_blocks = [
    data.aws_vpc.this.cidr_block
  ]
}

#################
# Network Interfaces
#################
resource "aws_network_interface" "private" {
  depends_on = [
    "aws_security_group.private"
  ]
  count = var.cluster_size
  subnet_id = element(data.aws_subnet.private.*.id, count.index % length(data.aws_subnet.private.*.id))
  private_ips_count = 0
  security_groups = [
    aws_security_group.private.id
  ]
  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-${local.broker_ids[count.index]}-private"))
}

#################
# EBS Storage
#################
resource "aws_ebs_volume" "storage1" {
  count = var.cluster_size * local.storage_ebs_flag
  availability_zone = element(data.aws_subnet.private.*.availability_zone, count.index % length(data.aws_subnet.private.*.availability_zone))
  encrypted = true
  kms_key_id = data.aws_kms_key.provided.arn
  size = var.storage_volume_size
  type = var.storage_volume_type
  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-broker-${local.broker_ids[count.index]}-d1"))
  lifecycle {
    ignore_changes = [
      "encrypted",
      "iops",
      "kms_key_id",
      "snapshot_id",
      "type"
    ]
  }
}

resource "aws_ebs_volume" "storage2" {
  count = var.cluster_size * local.storage_ebs_flag
  availability_zone = element(data.aws_subnet.private.*.availability_zone, count.index % length(data.aws_subnet.private.*.availability_zone))
  encrypted = true
  kms_key_id = data.aws_kms_key.provided.arn
  size = var.storage_volume_size
  type = var.storage_volume_type
  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-broker-${local.broker_ids[count.index]}-d2"))
  lifecycle {
    ignore_changes = [
      "encrypted",
      "iops",
      "kms_key_id",
      "snapshot_id",
      "type"
    ]
  }
}

resource "aws_ebs_volume" "storage3" {
  count = var.cluster_size * local.storage_ebs_flag
  availability_zone = element(data.aws_subnet.private.*.availability_zone, count.index % length(data.aws_subnet.private.*.availability_zone))
  encrypted = true
  kms_key_id = data.aws_kms_key.provided.arn
  size = var.storage_volume_size
  type = var.storage_volume_type
  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-broker-${local.broker_ids[count.index]}-d3"))
  lifecycle {
    ignore_changes = [
      "encrypted",
      "iops",
      "kms_key_id",
      "snapshot_id",
      "type"
    ]
  }
}

#################
# EC2 Instance
#################
data "template_file" "user_data" {
  count = var.cluster_size
  template = file("${path.module}/kafka-user-data.tpl")

  vars = {
    storage_set_size = 3
    storage_type = var.storage_type

    broker_id = local.broker_ids[count.index]
    broker_rack = element(data.aws_subnet.private.*.availability_zone, count.index % length(data.aws_subnet.private.*.availability_zone))
    zookeeper = local.zookeeper_connect
    bootstrap_servers = "PLAINTEXT://${aws_route53_record.private[0].fqdn}:${var.broker_port}"

    // Format: ${listener_name}:${security_protocol}[,...]
    protocol_map = "BROKER:PLAINTEXT,CLIENT:PLAINTEXT,INTERNAL:PLAINTEXT,EXTERNAL:PLAINTEXT"

    // Format: ${listener_name}://${host_or_ip_address}:${port_number}
    broker_listener = "BROKER://${aws_network_interface.private[count.index].private_ip}:${var.broker_port}"
    client_listener = "CLIENT://${aws_network_interface.private[count.index].private_ip}:${var.plaintext_port}"

    broker_advertised_listener = "BROKER://${aws_network_interface.private[count.index].private_ip}:${var.broker_port}"
    client_advertised_listener = "CLIENT://${aws_network_interface.private[count.index].private_ip}:${var.plaintext_port}"
  }
}

resource "aws_instance" "broker" {
  depends_on = [
    "aws_network_interface.private",
    "aws_ebs_volume.storage1",
    "aws_ebs_volume.storage2",
    "aws_ebs_volume.storage3",
  ]
  count = var.cluster_size
  ami = var.ami_id
  instance_type = var.instance_type
  subnet_id = element(data.aws_subnet.private.*.id, count.index % length(data.aws_subnet.private.*.id))
  vpc_security_group_ids = [
    aws_security_group.private.id
  ]
  key_name = var.key_pair_name

  ebs_optimized = local.storage_ebs_flag > 0

  user_data = data.template_file.user_data[count.index].rendered

  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-broker-${local.broker_ids[count.index]}", "broker.id", local.broker_ids[count.index]))

  lifecycle {
//    ignore_changes = ["*"]
  }
}

#################
# Alarms
#################
resource "aws_cloudwatch_metric_alarm" "reboot" {
  count = local.instance_type_support_recovery ? length(aws_instance.broker) : 0
  alarm_actions = [
    "arn:aws:automate:${data.aws_region.current.name}:ec2:reboot"
  ]
  alarm_description = "Reboot Linux instance when Instance status check failed for 5 minutes"
  alarm_name = "${var.prefix}-kafka-broker-${local.broker_ids[count.index]}-reboot"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = 5
  evaluation_periods = 5
  threshold = 1
  metric_name = "StatusCheckFailed_Instance"
  namespace = "AWS/EC2"
  period = 60
  statistic = "Maximum"
  dimensions = {
    InstanceId = aws_instance.broker[count.index].id
  }
  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-broker-${local.broker_ids[count.index]}-reboot"))
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_metric_alarm" "recovery" {
  count = local.instance_type_support_recovery ? length(aws_instance.broker) : 0
  alarm_actions = [
    "arn:aws:automate:${data.aws_region.current.name}:ec2:recover"
  ]
  alarm_description = "Recover Linux instance when System status check failed for 10 minutes"
  alarm_name = "${var.prefix}-kafka-broker-${local.broker_ids[count.index]}-recovery"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = 10
  evaluation_periods = 10
  threshold = 1
  metric_name = "StatusCheckFailed_System"
  namespace = "AWS/EC2"
  period = 60
  statistic = "Maximum"
  dimensions = {
    InstanceId = aws_instance.broker[count.index].id
  }
  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-broker-${local.broker_ids[count.index]}-recovery"))
  lifecycle {
    create_before_destroy = true
  }
}

#################
# EBS Storage Attachments
#################
resource "aws_volume_attachment" "storage1" {
  depends_on = [
    "aws_ebs_volume.storage1",
    "aws_instance.broker"
  ]
  count = var.cluster_size * local.storage_ebs_flag
  device_name = "/dev/sdf"
  instance_id = aws_instance.broker[count.index].id
  volume_id = aws_ebs_volume.storage1[count.index].id
  force_detach = true
}

resource "aws_volume_attachment" "storage2" {
  depends_on = [
    "aws_ebs_volume.storage2",
    "aws_instance.broker"
  ]
  count = var.cluster_size * local.storage_ebs_flag
  device_name = "/dev/sdg"
  instance_id = aws_instance.broker[count.index].id
  volume_id = aws_ebs_volume.storage2[count.index].id
  force_detach = true
}

resource "aws_volume_attachment" "storage3" {
  depends_on = [
    "aws_ebs_volume.storage3",
    "aws_instance.broker"
  ]
  count = var.cluster_size * local.storage_ebs_flag
  device_name = "/dev/sdh"
  instance_id = aws_instance.broker[count.index].id
  volume_id = aws_ebs_volume.storage3[count.index].id
  force_detach = true
}

#################
# Network Interface Attachments
#################
resource "aws_network_interface_attachment" "broker" {
  depends_on = [
    "aws_network_interface.private",
    "aws_instance.broker"
  ]
  count = var.cluster_size
  instance_id = aws_instance.broker[count.index].id
  network_interface_id = aws_network_interface.private[count.index].id
  device_index = 1
}

#################
# Route53 Records
#################
data "aws_route53_zone" "private" {
  count = length(var.private_zone_ids)
  zone_id = var.private_zone_ids[count.index]
}

resource "aws_route53_record" "private" {
  count = length(data.aws_route53_zone.private)

  zone_id = data.aws_route53_zone.private[count.index].zone_id
  name = "${var.prefix}-kafka-brokers.${data.aws_route53_zone.private[count.index].name}"
  type = "A"
  ttl = "3600"
  records = aws_network_interface.private.*.private_ip
}

#################
# Outputs
#################
output "bootstrap_servers_private" {
  value = join(",", formatlist("%s:${var.plaintext_port}", aws_route53_record.private.*.fqdn))
}
output "broker_ids" {
  value = data.null_data_source.broker-ids.*.outputs.id
}

output "zookeeper_kafka_connect" {
  value = local.zookeeper_connect
}
