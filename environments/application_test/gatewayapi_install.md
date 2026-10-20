helm version

helm repo add eks https://aws.github.io/eks-charts
helm repo update

Step 2 — Install Gateway API CRDs

kubectl apply --server-side=true \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.0/standard-install.yaml

verify :  kubectl get crd | grep gateway.networking.k8s.io

Step 3 — Install AWS LBC Gateway-specific CRDs

kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/config/crd/gateway/gateway-crds.yaml

kubectl get crd | grep gateway.k8s.aws

Step 4 — Create IAM policy for the Load Balancer Controller

curl -o iam_policy.json \
https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.16.0/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

Step 5 — Create the controller IAM role + ServiceAccount

eksctl create iamserviceaccount \
  --cluster dev-app-cluster \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::942548380800:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --region us-west-2 \
  --approve

kubectl get sa aws-load-balancer-controller -n kube-system -o yaml

Step 6 — Install AWS Load Balancer Controller

update the vpc id using :

aws eks describe-cluster \
>   --name dev-app-cluster \
>   --region us-west-2 \
>   --query "cluster.resourcesVpcConfig.vpcId" \
>   --output text

helm upgrade aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=dev-app-cluster \
  --set region=us-west-2 \
  --set vpcId=vpc-068ffbc2e9031214f \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller


  vpc-068ffbc2e9031214f

Step 7 — Verify the controller

kubectl get deployment -n kube-system aws-load-balancer-controller

kubectl get pods -n kube-system | grep aws-load-balancer

kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=50

Step 8 — Create the GatewayClass

kubectl apply -f gatewayclass.yaml

kubectl get gatewayclass

NAME       CONTROLLER           ACCEPTED
aws-alb    gateway.k8s.aws/alb   True

Step 9 — Configure internet-facing ALB

kubectl apply -f alb-config.yaml

# 3. TargetGroupConfiguration
kubectl apply -f tg-config.yaml

Step 10 — Create the Gateway

kubectl apply -f gateway.yaml

kubectl get gateway -n test

Step 11 — Create HTTPRoute

kubectl apply -f httproute.yaml

kubectl get httproute -n test

kubectl describe httproute nginx-route -n test

Step 12 — Check the complete chain

kubectl get gateway -n test

kubectl get httproute -n test

kubectl get svc -n test

kubectl get pods -n test

Step 13 — Test the ALB

Get the ALB addres

kubectl get gateway nginx-gateway -n test \
  -o jsonpath='{.status.addresses[0].value}'

curl http://k8s-test-nginx-xxxxxxxx.us-west-2.elb.amazonaws.com

Step 14 — Route 53


delete part
===========

kubectl delete httproute nginx-route -n test
kubectl delete gateway nginx-gateway -n test
kubectl delete loadbalancerconfiguration nginx-alb-config -n test

kubectl get gateway -n test

helm uninstall aws-load-balancer-controller -n kube-system

kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.0/standard-install.yaml

