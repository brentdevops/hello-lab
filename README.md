# hello-lab

A tiny app run the way teams run real services: container → Terraform on AWS → Kubernetes → CI/CD.

```
app.py                       15-line HTTP server: /  and  /health
Dockerfile                   python:3.12-slim, non-root
k8s/                         Deployment (probes, limits), NodePort Service, HPA
terraform/bootstrap/         PERMANENT: state bucket + GitHub OIDC + plan/deploy roles (run once, from your Mac)
terraform/                   per-environment: EC2 + k3s, ECR, security group, node IAM role, alarms
.github/workflows/
  pr.yml                     on PR:    terraform fmt/validate/plan (read-only role) + image build/scan
  deploy.yml                 on main:  terraform apply → build/scan/push (tag = commit) → deploy via SSM → smoke test
  destroy.yml                manual:   terraform destroy (cost guard)
scripts/kubeconfig.sh        kubectl access from your Mac via SSM (no SSH)
```

## Daily flow

```
start:  Actions → deploy  → Run workflow                     (~5 min, ~$0.03/hr after)
work:   git checkout -b my-change → edit → push → open PR    (checks run)
        merge the PR                                         (deploy runs)
look:   ./scripts/kubeconfig.sh && export KUBECONFIG=$PWD/kubeconfig && kubectl get pods
stop:   Actions → destroy → Run workflow → type "destroy"    ($0)
```

Your IP changed (hotspot)? Update the `MY_IP_CIDR` repo variable, then re-run **deploy**.

## One-time setup

1. `cd terraform/bootstrap && terraform apply`
2. GitHub → Settings → Secrets and variables → Actions → Variables:
   `AWS_REGION`, `AWS_PLAN_ROLE_ARN`, `AWS_DEPLOY_ROLE_ARN` (from bootstrap outputs), `MY_IP_CIDR` (`<your ip>/32`)

## Full teardown (including bootstrap)

Run **destroy** first, then `cd terraform/bootstrap && terraform destroy`.
