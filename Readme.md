eks module https://github.com/vamsidharterraform/eksmodule
rds module https://github.com/vamsidharterraform/rdsmodule
vpcmodule https://github.com/vamsidharterraform/vpcmodule

we have abpve three modules , create eks cluster using them.

we need addons , eks entries 

addons
| Add-on / Component | What it does | How it is linked |
|---|---|---|
| **AWS EBS CSI Driver** | Dynamically provisions and mounts EBS volumes for pods requiring persistent storage. | EKS Pod → EBS CSI Driver → IAM/IRSA Role → AWS EBS |
| **CloudWatch Observability** | Collects EKS/container logs and metrics and sends them to CloudWatch. | Pods/Nodes → CloudWatch Agent → Pod Identity → IAM Role → CloudWatch |
| **EKS Pod Identity Agent** | Provides AWS IAM credentials to pods without storing AWS keys. | Pod → Pod Identity Agent → IAM Role → AWS services |
| **AWS VPC CNI** | Provides pod networking using AWS VPC IP addresses and enables Kubernetes NetworkPolicy support. | Pod → VPC CNI → ENI/IP → VPC networking |
| **External Secrets Operator** | Synchronizes secrets from AWS Secrets Manager into Kubernetes Secrets. | ESO Pod → IRSA/OIDC IAM Role → Secrets Manager → Kubernetes Secret |
