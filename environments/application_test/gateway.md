# AWS Load Balancer Controller with Gateway API on EKS

A step-by-step guide to install the **AWS Load Balancer Controller (LBC)** with **Gateway API** support on Amazon EKS, expose an NGINX application through an internet-facing **ALB**, and map a domain with **Route 53**.

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Step 1: Install Helm and add the EKS chart repo](#step-1-install-helm-and-add-the-eks-chart-repo)
4. [Step 2: Install Gateway API CRDs](#step-2-install-gateway-api-crds)
5. [Step 3: Install AWS LBC Gateway-specific CRDs](#step-3-install-aws-lbc-gateway-specific-crds)
6. [Step 4: Create the IAM policy](#step-4-create-the-iam-policy-for-the-load-balancer-controller)
7. [Step 5: Create the IAM role and ServiceAccount](#step-5-create-the-controller-iam-role-and-serviceaccount)
8. [Step 6: Install the AWS Load Balancer Controller](#step-6-install-the-aws-load-balancer-controller)
9. [Step 7: Verify the controller](#step-7-verify-the-controller)
10. [Step 8: Create the GatewayClass](#step-8-create-the-gatewayclass)
11. [Step 9: Configure an internet-facing ALB](#step-9-configure-an-internet-facing-alb)
12. [Step 10: Create the Gateway](#step-10-create-the-gateway)
13. [Step 11: Create the HTTPRoute](#step-11-create-the-httproute)
14. [Step 12: Check the complete chain](#step-12-check-the-complete-chain)
15. [Step 13: Test the ALB](#step-13-test-the-alb)
16. [Step 14: Configure Route 53](#step-14-configure-route-53)
17. [Troubleshooting](#troubleshooting)
18. [Quick Reference](#quick-reference)

---

## Overview

### What gets installed

| Order | Component | Purpose |
|-------|-----------|---------|
| 1 | Helm | Package manager used to install the controller |
| 2 | Gateway API CRDs | Kubernetes types: `GatewayClass`, `Gateway`, `HTTPRoute` |
| 3 | AWS LBC Gateway CRDs | AWS types: `LoadBalancerConfiguration`, `TargetGroupConfiguration`, `ListenerRuleConfiguration` |
| 4 to 5 | IAM policy, role and ServiceAccount | Permissions for the controller to manage AWS load balancers |
| 6 | AWS Load Balancer Controller | Watches Gateway API objects and creates the ALB, listeners, rules and target groups |

### Resource chain created in this guide

```text
GatewayClass (aws-alb)
      |
      v
Gateway (nginx-gateway)  <---- LoadBalancerConfiguration (internet-facing)
      |
      v
HTTPRoute (nginx-route)
      |
      v
Service (nginx)  -->  Pods
      |
      v
AWS ALB  -->  Route 53 domain
```

### Values used in this guide

Replace these with your own values.

| Item | Value used |
|------|-----------|
| EKS cluster name | `dev-app-cluster` |
| AWS region | `us-west-2` |
| AWS account ID | `942548380800` |
| Application namespace | `test` |
| Gateway name | `nginx-gateway` |
| HTTPRoute name | `nginx-route` |
| GatewayClass name | `aws-alb` |
| Controller IAM policy | `AWSLoadBalancerControllerIAMPolicy` |

---

## Prerequisites

Make sure the following are in place before you start:

- An **EKS cluster** (`dev-app-cluster`) and `kubectl` configured to reach it.
- Installed CLIs: `aws`, `eksctl`, `kubectl`, `helm`, `curl`.
- An **IAM OIDC provider** associated with the cluster (needed for IAM roles for service accounts):

  ```bash
  eksctl utils associate-iam-oidc-provider \
    --cluster dev-app-cluster \
    --region us-west-2 \
    --approve
  ```

- **Subnets tagged** so the controller can discover them:
  - Public subnets (internet-facing ALB): `kubernetes.io/role/elb = 1`
  - Private subnets (internal ALB): `kubernetes.io/role/internal-elb = 1`
- A sample application **Deployment and Service** (for example `nginx`) running in namespace `test`.

---

## Step 1: Install Helm and add the EKS chart repo

**Purpose:** Helm installs the AWS Load Balancer Controller chart, which is published in the `eks` chart repository.

Check that Helm is installed:

```bash
helm version
```

Add the EKS chart repository and refresh the local index:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

**Verify:**

```bash
helm repo list
helm search repo eks/aws-load-balancer-controller
```

---

## Step 2: Install Gateway API CRDs

**Purpose:** Adds the standard Kubernetes Gateway API resource types (`GatewayClass`, `Gateway`, `HTTPRoute`, and so on) to the cluster.

```bash
kubectl apply --server-side=true \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.0/standard-install.yaml
```

**Verify:**

```bash
kubectl get crd | grep gateway.networking.k8s.io
```

You should see entries such as `gatewayclasses`, `gateways` and `httproutes`.

---

## Step 3: Install AWS LBC Gateway-specific CRDs

**Purpose:** Adds the AWS-specific custom resources used to configure the ALB (`LoadBalancerConfiguration`, `TargetGroupConfiguration`, `ListenerRuleConfiguration`).

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/config/crd/gateway/gateway-crds.yaml
```

**Verify:**

```bash
kubectl get crd | grep gateway.k8s.aws
```

> **Tip:** Install both CRD sets **before** the controller. If you install CRDs after the controller is already running, restart it so it detects them:
> `kubectl rollout restart deployment aws-load-balancer-controller -n kube-system`

---

## Step 4: Create the IAM policy for the Load Balancer Controller

**Purpose:** The controller needs AWS permissions to create and manage load balancers, target groups, listeners and security groups.

Download the policy document:

```bash
curl -o iam_policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.16.0/docs/install/iam_policy.json
```

Create the IAM policy:

```bash
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json
```

> **Note:** The policy version (`v2.16.0`) should match the controller version you install in Step 6. Use the policy file from the same release as your controller.

---

## Step 5: Create the controller IAM role and ServiceAccount

**Purpose:** Creates an IAM role linked to a Kubernetes ServiceAccount (IRSA), so the controller pod gets AWS permissions without static credentials.

```bash
eksctl create iamserviceaccount \
  --cluster dev-app-cluster \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::942548380800:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --region us-west-2 \
  --approve
```

| Flag | Meaning |
|------|---------|
| `--cluster` | EKS cluster name |
| `--namespace` / `--name` | Namespace and name of the ServiceAccount to create |
| `--attach-policy-arn` | IAM policy from Step 4 (replace the account ID with yours) |
| `--override-existing-serviceaccounts` | Reuse the ServiceAccount if it already exists |
| `--approve` | Apply the change without a dry run |

**Verify:**

```bash
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml
```

Look for the annotation `eks.amazonaws.com/role-arn` pointing to the created IAM role.

---

## Step 6: Install the AWS Load Balancer Controller

**Purpose:** Deploys the controller with Gateway API (ALB) support enabled.

```bash
helm install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=dev-app-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set controllerConfig.featureGates.ALBGatewayAPI=true
```

| Setting | Meaning |
|---------|---------|
| `clusterName` | Your EKS cluster name |
| `serviceAccount.create=false` | Do not create a ServiceAccount; use the one from Step 5 |
| `serviceAccount.name` | Name of the existing ServiceAccount |
| `controllerConfig.featureGates.ALBGatewayAPI=true` | Turns on Gateway API support for ALB (Layer 7) |

> **Note:** On newer controller versions Gateway API support may be enabled automatically when the CRDs exist. Keeping the feature gate set explicitly is harmless and makes the intent clear.

---

## Step 7: Verify the controller

Check the Deployment:

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

Check the pods (they should be `Running` and `Ready`):

```bash
kubectl get pods -n kube-system | grep aws-load-balancer
```

Check the logs for errors:

```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=50
```

---

## Step 8: Create the GatewayClass

**Purpose:** The `GatewayClass` tells Kubernetes that Gateways of this class are managed by the AWS Load Balancer Controller in ALB mode.

Example `gatewayclass.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: aws-alb
spec:
  controllerName: gateway.k8s.aws/alb
```

Apply and verify:

```bash
kubectl apply -f gatewayclass.yaml
kubectl get gatewayclass
```

Expected output:

```text
NAME       CONTROLLER            ACCEPTED
aws-alb    gateway.k8s.aws/alb   True
```

`ACCEPTED = True` means the controller recognised the class.

---

## Step 9: Configure an internet-facing ALB

**Purpose:** The `LoadBalancerConfiguration` holds AWS-specific ALB settings, such as whether the ALB is public or internal.

Example `alb-config.yaml`:

```yaml
apiVersion: gateway.k8s.aws/v1
kind: LoadBalancerConfiguration
metadata:
  name: alb-config
  namespace: test
spec:
  scheme: internet-facing
```

Apply:

```bash
kubectl apply -f alb-config.yaml
```

> **Rule:** The `LoadBalancerConfiguration` must be in the **same namespace as the Gateway** that references it.

---

## Step 10: Create the Gateway

**Purpose:** The `Gateway` requests the ALB and defines its listeners (port and protocol).

Example `gateway.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: nginx-gateway
  namespace: test
spec:
  gatewayClassName: aws-alb
  infrastructure:
    parametersRef:
      group: gateway.k8s.aws
      kind: LoadBalancerConfiguration
      name: alb-config
  listeners:
    - name: http
      protocol: HTTP
      port: 80
```

| Field | Meaning |
|-------|---------|
| `gatewayClassName` | Links to the GatewayClass from Step 8 |
| `infrastructure.parametersRef` | Attaches the LoadBalancerConfiguration from Step 9 |
| `listeners` | ALB listener on port 80 (HTTP). Routes attach to it using `sectionName: http` |

Apply and verify:

```bash
kubectl apply -f gateway.yaml
kubectl get gateway -n test
```

Wait until the Gateway shows an `ADDRESS` (the ALB DNS name) and `PROGRAMMED = True`. This can take a few minutes while AWS provisions the ALB.

---

## Step 11: Create the HTTPRoute

**Purpose:** The `HTTPRoute` defines routing rules and sends traffic from the Gateway to your Kubernetes Service.

Example `httproute.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: nginx-route
  namespace: test
spec:
  parentRefs:
    - name: nginx-gateway
      sectionName: http
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: nginx
          port: 80
```

| Field | Meaning |
|-------|---------|
| `parentRefs` | Attaches the route to `nginx-gateway`, listener `http` |
| `matches` | Match all paths starting with `/` |
| `backendRefs` | Forward to Service `nginx` on port `80` (change to your Service name and port) |

Apply and verify:

```bash
kubectl apply -f httproute.yaml
kubectl get httproute -n test
kubectl describe httproute nginx-route -n test
```

In the `describe` output, check under **Status > Parents** that both conditions are true:

- `Accepted = True` (the route attached to the Gateway)
- `ResolvedRefs = True` (the backend Service and port were found)

---

## Step 12: Check the complete chain

Verify every layer from the Gateway down to the Pods:

```bash
kubectl get gateway -n test
kubectl get httproute -n test
kubectl get svc -n test
kubectl get pods -n test
```

Checklist:

- [ ] Gateway has an `ADDRESS` and is `Programmed`
- [ ] HTTPRoute is `Accepted` and `ResolvedRefs`
- [ ] Service exists and its `targetPort` matches the container port
- [ ] Pods are `Running` and `Ready`

---

## Step 13: Test the ALB

Get the ALB address from the Gateway status:

```bash
kubectl get gateway nginx-gateway -n test \
  -o jsonpath='{.status.addresses[0].value}'
```

Call it with `curl` (use the address returned above):

```bash
curl http://k8s-test-nginx-xxxxxxxx.us-west-2.elb.amazonaws.com
```

You should receive the NGINX welcome page. A newly created ALB can take a minute or two before DNS resolves and targets become healthy.

---

## Step 14: Configure Route 53

**Purpose:** Map a friendly domain name (for example `app.example.com`) to the ALB.

### Using the AWS Console

1. Open **Route 53 > Hosted zones** and select your hosted zone.
2. Choose **Create record**.
3. Fill in the record:

   | Field | Value |
   |-------|-------|
   | Record name | `app` (for `app.example.com`) |
   | Record type | `A - Routes traffic to an IPv4 address and some AWS resources` |
   | Alias | **On** |
   | Route traffic to | **Alias to Application and Classic Load Balancer** |
   | Region | `US West (Oregon) us-west-2` |
   | Load balancer | Select the ALB created for the Gateway |

4. Choose **Create records**.

### Verify DNS

```bash
nslookup app.example.com
curl http://app.example.com
```

> **Tip:** To find the ALB programmatically, use `aws elbv2 describe-load-balancers --region us-west-2`. The output shows each ALB's `DNSName` and `CanonicalHostedZoneId`, which are needed for an alias record created through the CLI.

> **Production note:** Add an HTTPS listener (port 443) with an ACM certificate and redirect HTTP to HTTPS before exposing the application publicly.

---

## Troubleshooting

| Symptom | Likely cause | What to check or do |
|---------|--------------|---------------------|
| GatewayClass `ACCEPTED` is not `True` | Wrong `controllerName`, CRDs missing, or controller not running | Confirm `gateway.k8s.aws/alb`; check CRDs (Steps 2 and 3); restart the controller |
| Gateway has no `ADDRESS` | ALB not created yet, subnet tags missing, or IAM permissions missing | Wait a few minutes; check subnet tags; read controller logs |
| Controller pod `CrashLoopBackOff` | IAM role or ServiceAccount problem, wrong `clusterName` | Check `kubectl logs`; verify the IRSA annotation (Step 5) |
| HTTPRoute not `Accepted` | Wrong `parentRefs` name or `sectionName`, or namespace not allowed | Match the Gateway name and listener name exactly; check `allowedRoutes` |
| HTTPRoute `ResolvedRefs = False` | Service name or port wrong | Fix `backendRefs` to match `kubectl get svc -n test` |
| ALB returns `503` or targets unhealthy | Pods not ready, wrong `targetPort`, health check failing | Check pods, Service port mapping and target health in **EC2 > Target Groups** |
| `curl` cannot resolve the ALB name | ALB still provisioning | Wait 1 to 2 minutes and retry |

### Useful debugging commands

```bash
kubectl describe gateway nginx-gateway -n test
kubectl describe httproute nginx-route -n test
kubectl get endpoints -n test
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=100
```

---

## Quick Reference

All commands in order:

```bash
# Step 1: Helm
helm version
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Step 2: Gateway API CRDs
kubectl apply --server-side=true \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.0/standard-install.yaml
kubectl get crd | grep gateway.networking.k8s.io

# Step 3: AWS LBC Gateway CRDs
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/config/crd/gateway/gateway-crds.yaml
kubectl get crd | grep gateway.k8s.aws

# Step 4: IAM policy
curl -o iam_policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.16.0/docs/install/iam_policy.json
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

# Step 5: IAM role + ServiceAccount
eksctl create iamserviceaccount \
  --cluster dev-app-cluster \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::942548380800:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --region us-west-2 \
  --approve
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml

# Step 6: Install the controller
helm install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=dev-app-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set controllerConfig.featureGates.ALBGatewayAPI=true

# Step 7: Verify the controller
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system | grep aws-load-balancer
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=50

# Steps 8 to 11: Gateway API resources
kubectl apply -f gatewayclass.yaml
kubectl get gatewayclass
kubectl apply -f alb-config.yaml
kubectl apply -f gateway.yaml
kubectl get gateway -n test
kubectl apply -f httproute.yaml
kubectl get httproute -n test
kubectl describe httproute nginx-route -n test

# Step 12: Check the chain
kubectl get gateway -n test
kubectl get httproute -n test
kubectl get svc -n test
kubectl get pods -n test

# Step 13: Test
kubectl get gateway nginx-gateway -n test \
  -o jsonpath='{.status.addresses[0].value}'
curl http://<alb-dns-name>
```

---

### Notes on this document

The commands come from your original notes. These parts were **added** to make the guide complete: the prerequisites, the example YAML for `gatewayclass.yaml`, `alb-config.yaml`, `gateway.yaml` and `httproute.yaml` (your notes only referenced the files), the Route 53 steps (the section was empty), and the troubleshooting table. Adjust names, namespaces, ports and the AWS account ID to match your environment.