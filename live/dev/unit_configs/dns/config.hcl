# Set once the AWS Load Balancer Controller provisioned the internal ALB
# from the frontend chart's Ingress (`kubectl get ingress -n frontend`,
# `aws elbv2 describe-load-balancers` for the hosted zone ID). If the
# frontend Ingress is ever deleted and recreated, the controller allocates a
# brand new ALB with a new DNS name -- update these and re-apply.
inputs = {
  alb_dns_name = "internal-k8s-frontend-cmfronte-b27f3aee6b-1886293586.us-east-2.elb.amazonaws.com"
  alb_zone_id  = "Z3AADJGX6KTTL2"
}
