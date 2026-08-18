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
  }
}
