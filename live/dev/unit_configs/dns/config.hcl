# alb_dns_name / alb_zone_id are left unset until the AWS Load Balancer
# Controller has provisioned the internal ALB from the frontend Ingress.
# Once you have those (e.g. `kubectl get ingress` / describe the ALB),
# add them here and re-apply to create the alias A record:
#
# inputs = {
#   alb_dns_name = "internal-xxxx.us-east-2.elb.amazonaws.com"
#   alb_zone_id  = "ZLMOA37VPKANP"
# }

inputs = {}
