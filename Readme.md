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

Simple interconnection

                    EKS Cluster
                        |
       +----------------+----------------+
       |                |                |
    VPC CNI        Pod Identity       EBS CSI
       |                |                |
   Pod Network      IAM Roles       EBS Volumes
                        |
              +---------+---------+
              |                   |
        CloudWatch           Secrets Manager
       Observability          via ESO

Interview summary:  
"We use VPC CNI for pod networking, EBS CSI for persistent storage, Pod Identity for AWS IAM access, CloudWatch Observability for monitoring and logging, and External Secrets Operator to securely synchronize Secrets Manager secrets into Kubernetes."

==================================================access entries ===============================

You have 2 EKS access entries explicitly configured in this Terraform code.
#	Access Entry	Principal	Access Policy	Scope
1	terraform_admin	arn:aws:iam::942548380800:user/terraform	AmazonEKSClusterAdminPolicy	Cluster
2	gitlab_deploy	gitlab-eks-deploy-role	AmazonEKSClusterAdminPolicy	Cluster


Relationship
Terraform IAM User
      |
      v
EKS Access Entry
      |
      v
AmazonEKSClusterAdminPolicy
      |
      v
EKS Cluster
GitLab IAM Role
      |
      v
EKS Access Entry
      |
      v
AmazonEKSClusterAdminPolicy
      |
      v
EKS Cluster
Important distinction
You also have IAM roles, but they are not EKS access entries:
- EKS Cluster IAM Role → allows EKS service to manage the cluster.
- Worker Node IAM Role → used by EC2 worker nodes.
- CloudWatch IAM Role → used by CloudWatch agent.
- EBS CSI IAM Role → used by EBS CSI driver.
- External Secrets IAM Role → used by External Secrets Operator.
So for interview purposes:
"We have two EKS access entries: one for the Terraform administrator and one for the GitLab deployment role. Both are associated with the AmazonEKSClusterAdminPolicy at cluster scope."

Also, your cluster uses:

authentication_mode = "API_AND_CONFIG_MAP"

So EKS access entries and the legacy aws-auth ConfigMap can coexist. The code you've shown explicitly creates 2 API-based access entries.

=========================================================================================================================================

1. IAM Role vs EKS Access Entry
	IAM Role	EKS Access Entry
Purpose	Gives an AWS identity permissions to AWS services	Gives an IAM principal access to the EKS Kubernetes API
Scope	AWS account/services	Specific EKS cluster
Example	gitlab-eks-deploy-role	Access entry for gitlab-eks-deploy-role
Provides	AWS API permissions	EKS/Kubernetes authentication + cluster access policy
Created using	aws_iam_role	aws_eks_access_entry
By itself	Doesn't automatically mean Kubernetes access	References an existing IAM user/role


2. Your GitLab example
You actually have both:
GitLab
   |
   v
IAM Role
gitlab-eks-deploy-role
   |
   +---- AWS permissions
   |       |
   |       +--> eks:DescribeCluster
   |       +--> ECR permissions, etc.
   |
   v
EKS Access Entry
   |
   v
AmazonEKSClusterAdminPolicy
   |
   v
EKS Kubernetes API
So the IAM role is the identity, while the EKS access entry connects that identity to the EKS cluster.
How many IAM roles did you create?
In the code you provided, there are 4 IAM roles created/referenced.
#	IAM Role	Terraform Resource	Purpose
1	<cluster>-cluster-role	aws_iam_role.cluster	EKS control plane
2	<cluster>-node-role	aws_iam_role.node	EKS worker nodes
3	<cluster>-cloudwatch-observability-role	aws_iam_role.cloudwatch_observability	CloudWatch Observability
4	<cluster>-external-secrets-role	aws_iam_role.external_secrets	External Secrets → Secrets Manager


Additionally, you have:
data "aws_iam_role" "gitlab_deploy"
This does NOT create a role.
It looks up an existing IAM role:
gitlab-eks-deploy-role
So if the question is:
"How many IAM roles are created by this Terraform code?"
4 roles.
"How many IAM roles are involved/referenced?"
5 roles — the 4 created above + the existing GitLab deployment role.
One more important distinction
Your 2 EKS access entries are:
1. Terraform IAM User
       ↓
   EKS Access Entry

2. GitLab IAM Role
       ↓
   EKS Access Entry
Notice that the first principal is an IAM User, not an IAM Role.
So your architecture has:
IAM identities
│
├── Terraform IAM User
│       └── EKS Access Entry
│
└── GitLab IAM Role
        └── EKS Access Entry


EKS service roles
│
├── Cluster Role
├── Node Role
├── CloudWatch Role
└── External Secrets Role
Interview one-liner:
"IAM roles define AWS identities and permissions, whereas EKS access entries authorize those IAM principals to authenticate to a specific EKS cluster and associate them with EKS access policies."