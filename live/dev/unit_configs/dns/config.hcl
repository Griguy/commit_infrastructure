# Set to whichever ALB currently backs the frontend/Grafana IngressGroup
# (`kubectl get ingress -A`, `aws elbv2 describe-load-balancers` for the
# hosted zone ID). Grouping or ungrouping Ingresses under
# alb.ingress.kubernetes.io/group.name makes the controller provision a
# *new* ALB and drop the old one -- its DNS name changes every time that
# happens, not just on first creation. Update these and re-apply whenever
# it does.
#
# Empty until the ALB exists (left unset deliberately after the
# us-east-2 -> eu-central-1 region migration -- the old values pointed at
# an ALB that no longer exists, in a hosted zone ID that belongs to the
# wrong region's ELB service anyway).
inputs = {}
