# hello-lab

A tiny app taken all the way: container → Terraform on AWS → k3s → CI/CD → monitoring → break it.

```
app.py                     15-line HTTP server: /  and  /health
Dockerfile                 python:3.12-slim, non-root
terraform/bootstrap/       S3 bucket for remote state (local state)
terraform/                 EC2 t3.small + k3s, ECR, IAM (node role + GitHub OIDC role), SG, CloudWatch alarms
k8s/                       Deployment (probes, requests/limits), NodePort Service, HPA
.github/workflows/         build → Trivy scan → push to ECR (tag = git SHA) → deploy via SSM
```

## Cost
~$0.03/hr (t3.small + public IPv4 + 20 GB gp3). ~$0.60/day if forgotten.

## Teardown (do this at the end)
```bash
cd terraform           && terraform destroy -var-file=lab.tfvars
cd bootstrap           && terraform destroy
```
Check that nothing is left:
```bash
aws ec2 describe-instances --filters Name=tag:Project,Values=hello-lab \
  Name=instance-state-name,Values=running --query 'Reservations[].Instances[].InstanceId'
```
