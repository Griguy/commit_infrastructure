# cm_infrastructure

Terraform/Terragrunt IaC for a private AWS lab environment: VPC, EKS (Auto Mode), RDS Postgres, a Windows SSM-only management host, Route53/ACM, and the AWS side of a GitOps-deployed application with autoscaling and telemetry. This repo provisions the AWS infrastructure; the application, GitOps, and Helm-chart layers live in four sibling repos described in [System architecture](#system-architecture) below.

## How to access the Windows management host

Read this section first — it's the only way to actually see the application or any dashboard, since nothing in this environment is reachable from outside the VPC.

The Windows instance has no key-pair and no public IP. Access is exclusively via AWS Systems Manager Session Manager port forwarding, tunneled over PrivateLink — there is no VPN, no bastion, and no inbound path from the internet at all.

**Get the current instance ID and admin password** (don't trust old copies of these — the password is a `random_password` Terraform resource, so it only ever changes if that unit is destroyed and recreated, but always re-check rather than assume):

```bash
cd live/dev/.terragrunt-stack/windows
terragrunt output -raw windows_instance_id
terragrunt output -raw windows_admin_password
```

> Why isn't the password just written here in plain text? Reaching a point where the password is even useful requires already having valid AWS IAM credentials with SSM permissions on this account/instance to open the tunnel below — the instance has no public IP and no inbound path from the internet, so the password alone, with no AWS access, unlocks nothing. Even so, a real secret sitting permanently in git history is a bad habit worth not forming even when it happens to be low-risk here — and git history is far harder to truly scrub after the fact than to just not commit it in the first place (ask about this session's own experience clawing a different file back out of history if you want the long version). The `terragrunt output` command above is the actual source of truth and always reflects the current value.

**Open the tunnel** (run this on your own machine, in a terminal you leave running):

```bash
aws ssm start-session \
  --target <instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3389"],"localPortNumber":["13389"]}'
```

**Trust the self-signed certificate, once, inside that Windows session** (otherwise every HTTPS page load shows a cert warning):

1. Fetch the cert PEM: `aws acm get-certificate --certificate-arn arn:aws:acm:us-east-2:276699358299:certificate/0572f4f6-d3c0-4004-9eb7-1133e5bf6d39 --region us-east-2 --query Certificate --output text`
2. Paste it into Notepad *inside* the RDP session, save as `C:\lab-commit-ca.crt` with **"Save as type: All Files"** (Notepad silently appends `.txt` otherwise).
3. From an elevated Command Prompt: `certutil -addstore -f "ROOT" C:\lab-commit-ca.crt`
4. Close and reopen the browser.

**Browse to**:
- `https://lab-commit-task.commit-lab.internal` — the frontend app
- `https://lab-commit-task.commit-lab.internal/grafana` — Grafana. Username `admin`; the password is chart-generated and **changes on every meaningful Argo CD sync** of `kube-prometheus-stack` (no static `adminPassword` is set), so always fetch the current one rather than reusing an old value:
  ```bash
  kubectl get secret -n monitoring kube-prometheus-stack-grafana \
    -o jsonpath='{.data.admin-password}' | base64 -d
  ```

Both hostnames only resolve inside this VPC (private Route53 hosted zone) — that's not a coincidence, it's the actual proof the app isn't exposed to the internet.

## System architecture

### Repository layout

Five repos, each with one job:

| Repo | Role |
|---|---|
| **`cm_infrastructure`** (this repo) | Terraform/Terragrunt for every AWS resource: VPC, EKS, RDS, Route53/ACM, the Windows host, ECR, CodePipeline/CodeBuild, IAM/IRSA roles. |
| **`cm_gitops`** | Argo CD "app of apps" — `bootstrap/root-app.yaml` (applied once by hand, watches everything else), `apps/platform/*` for cluster-wide add-ons (ALB controller, kube-prometheus-stack, otel-collector, KEDA, the k6 load generator), `apps/services/*` for the app Deployments, `envs/dev/*/values.yaml` for per-environment chart values that CI writes to. |
| **`cm_charts`** | The Helm charts themselves for `cm-backend`/`cm-frontend`. Changes rarely, tagged releases (`backend-0.1.0`, `frontend-0.1.0`, ...) — `cm_gitops`'s Applications pin to a specific tag, never `main`, so a template edit here doesn't go live anywhere until that pin is explicitly bumped. |
| **`cm_backend`** | Backend app source (Node.js), Dockerfile, `buildspec.yml`. Connects to RDS, exposes `GET /api/value` (a `SELECT`), `/healthz`, `/readyz`. |
| **`cm_frontend`** | Frontend app source (Node.js), Dockerfile, `buildspec.yml`. Serves the page showing `Hello Lab-Commit <version> - DB Value: <n>`, polling its own `/api/value` (which proxies to the backend) every 5 seconds. |

### Terragrunt unit structure

`units/` mirrors `modules/` one level deeper where a unit only exists to extend another (e.g. `eks/argocd`, `eks/irsa` have no reason to exist without `eks`, so they nest under it rather than sitting flat alongside it, keeping that ownership visible in the directory tree instead of just in a `dependency` block; a nested unit reaches its parent via `config_path = ".."`, not a sibling-style relative path, since it's already inside the parent's own directory):

```
units
├── cicd
│   ├── backend
│   │   └── terragrunt.hcl
│   ├── frontend
│   │   └── terragrunt.hcl
│   └── gitops-credential
│       └── terragrunt.hcl
├── codeconnection
│   └── terragrunt.hcl
├── dns
│   └── terragrunt.hcl
├── ecr
│   └── terragrunt.hcl
├── eks
│   ├── argocd
│   │   └── terragrunt.hcl
│   ├── db-secret
│   │   └── terragrunt.hcl
│   ├── irsa
│   │   └── terragrunt.hcl
│   └── terragrunt.hcl
├── rds
│   └── terragrunt.hcl
├── vpc
│   └── terragrunt.hcl
└── windows
    └── terragrunt.hcl
```

`live/dev/terragrunt.stack.hcl` is what actually turns these templates into the live `dev` stack (13 units total) — each `unit` block's `path` there controls both the unit's generated directory under `live/dev/.terragrunt-stack/` and its Terraform state's S3 key.

### AWS network and compute

- **VPC**: 2 private subnets (where everything actually runs — EKS, RDS, the Windows host) + 2 public subnets (host only that AZ's NAT Gateway, nothing else deployed there). One Internet Gateway, one NAT Gateway per AZ for outbound-only internet access (image pulls, ArgoCD's repo-server reaching Git/Helm repos). No inbound path from the internet anywhere.
- **EKS**: cluster `commit-lab-dev`, Auto Mode — no EC2 Managed Node Groups (forbidden by the task spec), Auto Mode's own managed compute instead, private-subnets-only.
- **RDS**: Postgres, private, `publicly_accessible = false`. Security group scoped to the private subnet CIDRs rather than a per-pod identity — EKS Auto Mode doesn't support Kubernetes "Security Groups for Pods" (no branch-ENI trunking on Auto Mode's managed compute; confirmed the hard way, see `INCIDENT-rds-pod-security-group.md`), so CIDR scoping is the tightest boundary actually enforceable at the network layer here. The database's own username/password remain the real access control; network reachability was never meant to be the sole gate.
- **Windows host**: private subnet, no key-pair (password set via `user_data`, not `get_password_data`), SSM Session Manager only — see the access section above. VPC interface endpoints for `ssm`/`ssmmessages`/`ec2messages` give the SSM Agent a path since it can't reach the public SSM endpoints directly from a private subnet.
- **Route53 + ACM**: private hosted zone `commit-lab.internal`, associated with the VPC. Self-signed cert (CN `lab-commit-task.commit-lab.internal`) generated via Terraform's `tls_self_signed_cert` and imported into ACM, terminated on an internal ALB. The zone's A record is a Terraform-managed alias pointed at whatever ALB the AWS Load Balancer Controller currently owns (see below — that ALB's identity changes any time its IngressGroup membership changes, so this record needs re-applying after that, documented inline in `live/dev/unit_configs/dns/config.hcl`).

### On the cluster

- **Namespaces**: `argocd`, `backend`, `frontend`, `monitoring` (kube-prometheus-stack), `observability` (otel-collector), `keda`, `load-testing`.
- **AWS Load Balancer Controller**: provisions an internal ALB from Ingress resources, `target-type: ip`. The frontend's Ingress and Grafana's Ingress are grouped onto the **same** ALB via `alb.ingress.kubernetes.io/group.name` (an Argo CD IngressGroup) — path-based routing, `/` → frontend, `/grafana` → Grafana, with Grafana given the lower `group.order` so its more specific rule is evaluated before the frontend's catch-all `/`.
- **`cm-backend` / `cm-frontend`**: deployed via Argo CD multi-source Applications — chart from `cm_charts` (tag-pinned), values from `cm_gitops`'s `envs/dev/<service>/values.yaml` (the file CI bumps `image.tag` in on every build).
- **Argo CD**: installed via a Terraform `helm_release` (`modules/eks/argocd`) as the one-time cluster bootstrap; everything deployed *on top of* the cluster after that is GitOps-managed from `cm_gitops`, not Terraform.
- **kube-prometheus-stack, otel-collector, KEDA**: see their own sections below.

## CI/CD setup explanation

Per-service CodePipeline + CodeBuild, Terraform-managed (`modules/cicd/pipeline`, `units/cicd/backend`, `units/cicd/frontend`), triggered by a push to the `dev` branch of `commit_backend`/`commit_frontend` on GitHub via a shared CodeStar Connection.

**Flow, end to end:**
1. Push to `dev` → CodeStar Connection webhook triggers the pipeline.
2. CodeBuild builds the image, tags it with the git commit SHA — via `CODEBUILD_RESOLVED_SOURCE_VERSION`, **not** `git rev-parse`, since CodePipeline hands CodeBuild a zip artifact with no `.git` directory at all (this broke the first real pipeline run, see `INCIDENT-*` history for the exact error).
3. Pushes to the service's ECR repository (`cm-backend`/`cm-frontend`, immutable tags).
4. Clones `cm_gitops` using an SSH deploy key (stored in Secrets Manager, injected as a `SECRETS_MANAGER`-type CodeBuild environment variable — the key material never touches the buildspec or any log).
5. Bumps `envs/dev/<service>/values.yaml`'s `image.tag` via `yq`, commits, pushes to `main` with a retry-with-rebase loop (handles two pipelines racing to push at once).
6. Argo CD picks up that commit automatically (`selfHeal: true`, polls Git every few minutes by default) and redeploys. To see it happen immediately instead of waiting for the poll:
   ```bash
   kubectl patch application <backend|frontend> -n argocd --type merge \
     -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
   ```

**Manual, one-time setup that can't be automated:**
- Authorizing the CodeStar Connection in the AWS Console (OAuth flow with GitHub — no API for this step).
- Adding the deploy key's public half to `commit_gitops`'s GitHub repo → Settings → Deploy keys, with **write access** checked.

## Telemetry setup explanation

Both apps are instrumented with OpenTelemetry (`node --require ./src/otel.js ...`), auto-instrumenting HTTP/Express (and `pg` for the backend), pushing OTLP to a single in-cluster otel-collector gateway Deployment.

**From there, the collector fans out to three places:**

1. **CloudWatch (native OTLP ingestion)** — `otlphttp/metrics` and `otlphttp/logs` exporters, SigV4-signed. The service name in the SigV4 credential scope has to be `"monitoring"` for metrics (not the default) — CloudWatch's OTLP metrics endpoint is a genuinely new feature (GA mid-2026) with its own quirks; see `INCIDENT-grafana-cloudwatch-promql.md` for the doubled-`/v1/metrics`-path bug this exact config hit and how it was found. Logs land in one log group (`/commit-lab/dev/otel`), `service.name` on each record distinguishes frontend from backend.
2. **A local Prometheus exporter on the same collector** — re-exposes the same ingested metrics in classic Prometheus format (distinct from CloudWatch's native histogram handling) on a dedicated port, scraped by kube-prometheus-stack's own Prometheus via a `ServiceMonitor`. This is what KEDA queries for autoscaling — no AWS credentials involved in a scaling decision at all. Requires `honorLabels: true` on the ServiceMonitor, or Prometheus's own service-discovery `job` label collides with and silently renames the app's `service.name`-derived `job` label to `exported_job`.
3. **A `prometheus` *receiver*** on the same collector, separately, federates a handful of specific container/pod metrics (`container_cpu_usage_seconds_total`, `container_memory_working_set_bytes`, `kube_deployment_status_replicas`) from the in-cluster Prometheus's own `/federate` endpoint and forwards those to CloudWatch too — neither app emits process/container-level metrics itself, so this is the only path those numbers have to reach CloudWatch at all.

**Known, currently-unresolved limitation**: Grafana's own CloudWatch panel doesn't work. Both of Grafana's available AWS-authenticated Prometheus-compatible datasource options — the generic "Prometheus" type's `sigV4Auth` toggle, and the dedicated `grafana-amazonprometheus-datasource` plugin — hardcode SigV4 signing to service name `"aps"` (Amazon Managed Prometheus) instead of `"monitoring"`, which CloudWatch's new endpoint actually requires. Confirmed via the plugin's own source code and by testing through Grafana's real query API (`/api/ds/query`), not its misleading legacy reverse-proxy test path, which returns a generic "missing auth token" error that looks like something else entirely. Full diagnosis in `INCIDENT-grafana-cloudwatch-promql.md`.

The working alternative right now: a native **CloudWatch Dashboard** (`commit-lab-cm-app-metrics`, `us-east-2`), or direct SigV4-signed PromQL queries against `https://monitoring.us-east-2.amazonaws.com/api/v1/query` (the exact botocore signing snippet is in `COMMANDS.md`). Grafana's own `cm-backend / cm-frontend` dashboard mixes datasources per panel — the two CloudWatch-backed panels (HTTP request rate, p95 duration) are currently broken for the reason above; the container CPU/memory and pod-replica-count panels use the cluster's own Prometheus directly and work fine.

## How to run load testing (and watch it scale)

**What's deployed:**
- **KEDA** (`apps/platform/keda.yaml`) — the autoscaling engine, creates and owns a `HorizontalPodAutoscaler` for the frontend automatically.
- A **`ScaledObject`** for `cm-frontend` (`apps/platform/frontend-scaledobject.yaml`): scales 1 → 4 replicas on
  ```
  sum(rate(http_server_request_duration_seconds_count{job="cm-frontend", http_route!~"/healthz|/readyz"}[2m])) > 10
  ```
  — i.e. more than 10 real requests/second, with liveness/readiness probe traffic explicitly excluded so idle health-check pings never trip it. 60-second cooldown before scaling back down once load subsides.
- A **k6 load generator** (`apps/platform/k6-load-generator.yaml`), deliberately starting at `replicas: 0` so a human controls when it runs.

**Run it:**
```bash
# Start — generates a sustained ~20 req/s against the frontend's in-cluster Service directly
kubectl scale deployment k6-load-generator -n load-testing --replicas=1

# Watch it scale
kubectl get hpa -n frontend -w
kubectl get pods -n frontend -w

# Stop, and watch it scale back down
kubectl scale deployment k6-load-generator -n load-testing --replicas=0
```

**Expected timeline**: scale-out should be visible within roughly KEDA's `pollingInterval` (15s) plus however long the 2-minute `rate()` window takes to reflect the new load — a minute or two in practice. Scale-down happens about 60 seconds (the `cooldownPeriod`) after the metric has been back under threshold for that whole window.

**One gotcha worth knowing**: don't manually force-sync the `root` Argo CD Application (`kubectl patch application root ... sync`) while the load generator is intentionally scaled up. `root-app.yaml` has an `ignoreDifferences` rule exempting the load generator's replica count from selfHeal specifically so a manual `kubectl scale` survives normal automated reconciliation — and it does, for ordinary automated sync cycles. But an explicitly manually-triggered sync was observed to revert the replica count back to the git-declared `0` anyway, for reasons not fully root-caused. See `INCIDENT-crd-ordering-and-serverside-apply.md` for what's known about it.

## Further reading

- `COMMANDS.md` — every AWS CLI / kubectl / Terraform command pattern used while building and debugging this, organized by topic, including the exact SigV4-signing snippet for querying CloudWatch's PromQL API directly.
- `INCIDENT-root-app-prune.md`, `INCIDENT-rds-pod-security-group.md`, `INCIDENT-grafana-cloudwatch-promql.md`, `INCIDENT-crd-ordering-and-serverside-apply.md` — detailed write-ups of real bugs hit while building this, root causes, and fixes. Worth reading before touching the areas they cover.
