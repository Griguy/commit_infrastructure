# Set to whichever ALB currently backs the frontend/Grafana IngressGroup
# (`kubectl get ingress -A`, `aws elbv2 describe-load-balancers` for the
# hosted zone ID). Grouping or ungrouping Ingresses under
# alb.ingress.kubernetes.io/group.name makes the controller provision a
# *new* ALB and drop the old one -- its DNS name changes every time that
# happens, not just on first creation. Update these and re-apply whenever
# it does.
inputs = {
  alb_dns_name = "internal-k8s-commitlabdev-00c45bff13-888213938.us-east-2.elb.amazonaws.com"
  alb_zone_id  = "Z3AADJGX6KTTL2"
}
