# Apache Kafka Cluster Terraform module

Terraform module which creates a cluster of Apache Kafka brokers along with 
Yahoo [CMAK](https://github.com/yahoo/CMAK) and LinkedIn [Cruise Control](https://github.com/linkedin/cruise-control).

## Available Features
* Multi-AZ Apache Kafka and Zookeeper clusters
* Dedicated Apache Zookeeper cluster
* Deployed with Yahoo [CMAK](https://github.com/yahoo/CMAK) (f.k.a Kafka Manager)
* Integrated with LinkedIn [Cruise Control](https://github.com/linkedin/cruise-control)
* Persistent EBS volumes for faster recovery
* Automatic reboot and EC2 instance recovery on status check failures
* EBS volumes encryption
* Features from the **[terraform-aws-camellia-image](https://github.com/ninthnails/terraform-aws-camellia-image)** AMI

## Dependencies
This module depends on the availability of the 
[terraform-aws-camellia-image](https://github.com/ninthnails/terraform-aws-camellia-image) AMI in your AWS account.

## Usage
```hcl
module "camellia" {
  source  = "ninthnails/camellia/aws"
  version = "1.3.0"

  manager_admin_password = "parameter/camellia-manager-admin-password"
  manager_lb_enabled = true
  manager_lb_acm_certificate_arn = "arn:aws:acm:us-east-2:111111111111:certificate/8d3d569c-74b2-4d7d-aea7-061c7aa0e8bc"

  vpc_id = "vpc-12345678"
  private_subnet_ids = ["subnet-12345678", "subnet-87654321"]
  public_subnet_ids = ["subnet-09876543", "subnet-56473821"]
  key_pair_name = "my-ssh-key-pair-name"
  public_zone_id = "Z20985FABH34A"
  allowed_cidrs = {
    ipv4 = [
      "10.20.0.0/20",
      "1.2.3.4/32"
    ]
    ipv6 = []
  }
  camellia_ami_id = data.aws_ami.camellia.id
  kafka_storage_type = "ebs"
  kafka_storage_volume_type = "gp2"
  kafka_cluster_size = 3
  zookeeper_cluster_size = 3
  tags = {
    Environment = "dev"
    Terraform = "true"
  }
}

data "aws_ami" "camellia" {
  name_regex = "camellia-kafka-2.5.1-hvm-*"
  owners = ["self"]
  filter {
    name = "state"
    values = ["available"]
  }
  most_recent = true
}
```

## Examples
* [AWS Private Cluster](examples/aws-private-cluster): A simple cluster only accessible from within the VPC.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.13 |
| aws | >= 2.70 |
| null | >= 3.1 |
| template | >= 2.1 |
