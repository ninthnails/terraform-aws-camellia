# Camellia Image Terraform module

Terraform module which creates Amazon Machine Images (AMI) for Camellia using HashiCorp Packer and AWS CodeBuild.

## Usage

```hcl
module "image" {
  source = "github.com/ninthnails/camellia-terraform//image"
  prefix = "camellia"
  packer_template = "aws-private.json"
  packer_instance_type = "t3a.micro"
  vpc_id = "vpc-54e70a3249a84d75f"
  subnet_ids = ["subnet-eb537de7850039a7f"]
  tags = {
    Terraform = "true"
  }
}
```

CodeBuild run is not automatically triggered. You need to execute the build command the command output.
For example:

```shell script
aws --region us-east-2 codebuild start-build --project-name camellia-kafka-automation-packer --source-version xyz...
```
