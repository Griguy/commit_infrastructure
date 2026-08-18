inputs = {
  roles = {
    otel-collector = {
      namespace            = "observability"
      service_account_name = "otel-collector"
      policy_arns          = ["arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"]
    }
    grafana = {
      namespace            = "monitoring"
      service_account_name = "kube-prometheus-stack-grafana"
      policy_arns = [
        "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess",
        "arn:aws:iam::aws:policy/CloudWatchLogsReadOnlyAccess",
      ]
    }
    aws-load-balancer-controller = {
      namespace            = "kube-system"
      service_account_name = "aws-load-balancer-controller"
      # Upstream policy is ~20 statements and changes across controller
      # releases, so it's kept as the vendored JSON file (fetched verbatim
      # from the aws-load-balancer-controller repo) instead of hand-copied
      # into HCL where it'd be easy to silently drift from upstream.
      inline_policies = {
        aws-load-balancer-controller = file("alb_controller_policy.json")
      }
    }
  }
}
