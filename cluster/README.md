# Camellia Cluster Terraform module

Terraform module which creates an Apache Kafka cluster, along with Apache Zookeeper, 
Yahoo Kafka Manager, LinkedIn Cruise Control; using Camellia Image.

## Usage

```hcl
module "cluster" {
  source = "github.com/ninthnails/camellia-terraform//cluster"
  vpc_id = "vpc-54e70a3249a84d75f"
  private_subnet_ids = ["subnet-eb537de7850039a7f", "subnet-8537db59a00e7e73f", "subnet-43d7d02859de7e7b4"]
  public_subnet_ids = ["subnet-f7a9300587ed735be", "subnet-f37e7e00a95bd7358", "subnet-4b7e7ed95820d7d34"]
  key_pair_name = "your-ssh-key-pair"
  private_zone_ids = ["Z26235352124435617534"]
  public_zone_id = "Z16896WKL9998"
  allowed_cidrs = ["10.0.0.0/16"]
  camellia_ami_id = "ami-585aa317630bd3064"
  zookeeper_cluster_size = 3
  kafka_cluster_size = 3
}
```

CodeBuild run is not automatically triggered. You need to execute the build command the command output.
For example:

```shell script
aws --region us-east-2 codebuild start-build --project-name camellia-kafka-automation-packer --source-version xyz...
```
