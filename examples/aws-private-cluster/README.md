# Private Camellia Cluster Example

Terraform example module which creates a Camellia private cluster in a AWS VPC. The cluster will only be accessible  
from within the VPC. The management tools are publicly accessible but restricted to define set of source IP addresses. 

## Requirements
To properly use this module, you will need:

* A public AWS Route53 Zone, ideally for your domain name (see HTTPS)
* An AWS System Manager Parameter Store parameter for the management tools admin password

### Optional for HTTPS
* A domain name you own
* A wildcard AWS Certificate Manager SSL/TLS certificate for your domain name

## Usage
If you already meeting the requirements, create an auto variables file such as `example.auto.tfvars` with at minimum these.
Otherwise see further below for more instructions.
```hcl-terraform
aws_region = "us-east-2"
kafka_cluster_size = 3
ssh_key_name = "my-ssh-key-pair-name"
public_zone_id = "Z20985FABH34A"
allowed_cidrs = {
  ipv4 = [
    "1.2.3.4/32"
  ]
  ipv6 = []
}
manager_admin_password = "parameter/camellia-manager-admin-password"
manager_lb_acm_certificate_arn = "arn:aws:acm:us-east-2:111111111111:certificate/8d3d569c-74b2-4d7d-aea7-061c7aa0e8bc"
```

Then run Terraform as usual:
```shell script
terraform workspace new lab
terraform init
terraform plan -out terraform.tfplan
terraform apply terraform.tfplan
```
Kafka bootstrap servers and other useful information will be printed out.


When you are down, delete the resources.
```shell script
terraform destroy
```

### AWS Route53 Zone
This will create a public domain apex in Route 53.
```shell script
aws --region us-east-2 route53 create-hosted-zone --name mydomainname.com
```
Use the zone ID for the `public_zone_id` variable.

### AWS Certificate Manager
_Optional if you want to use HTTPS on the load balance._
This will request a public certificate to be issue for your domain name. Creation is complete only if you validate \
ownership of the domain name by creating alias record in the (Route 53) DNS.
```shell script
aws --region us-east-2 acm request-certificate --domain-name my-prefix.mydomainname.com \
  --subject-alternative-names '*.my-prefix.mydomainname.com' --validation-method DNS 
```
Once created use the certificate ARN for the `manager_lb_acm_certificate_arn` variable.

### AWS System Manager Parameter Store
This will create a parameter holding the password for the admin user on the management tools, CMAK, Cruise Control, etc.
**NOTE**: currently only plain `String` type is supported.
```shell script
aws --region us-east-2 ssm put-parameter --name "parameter/camellia-manager-admin-password" \
  --type String --value CHANGE_IT
```
