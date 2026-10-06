#!/usr/bin/env bash
# Get kubectl access to the hello-lab cluster from your Mac. No SSH, no key file.
#
#   ./scripts/kubeconfig.sh
#   export KUBECONFIG=~/Downloads/hello-lab/kubeconfig
#   kubectl get nodes
#
# How: finds the server by its tag → asks AWS SSM to run `cat k3s.yaml` on it →
#      swaps 127.0.0.1 for the server's public IP → saves ./kubeconfig (gitignored).
# Uses YOUR AWS login (aws cli), same as `aws eks update-kubeconfig` would at work.
set -euo pipefail
REGION=us-east-1
OUT="$(cd "$(dirname "$0")/.." && pwd)/kubeconfig"

read -r ID IP < <(aws ec2 describe-instances --region "$REGION" \
  --filters Name=tag:Name,Values=hello-lab-node Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].[InstanceId,PublicIpAddress]' --output text)
[ "$ID" = "None" ] && { echo "no running hello-lab server. Run the deploy pipeline first."; exit 1; }
echo "server: $ID ($IP)"

CMD_ID=$(aws ssm send-command --region "$REGION" --instance-ids "$ID" \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["cat /etc/rancher/k3s/k3s.yaml"]' \
  --query Command.CommandId --output text)

for _ in $(seq 1 20); do
  STATUS=$(aws ssm get-command-invocation --region "$REGION" --command-id "$CMD_ID" \
    --instance-id "$ID" --query Status --output text 2>/dev/null || echo Pending)
  case "$STATUS" in Pending|InProgress|Delayed) sleep 2 ;; *) break ;; esac
done
[ "$STATUS" = "Success" ] || { echo "SSM command ended with: $STATUS"; exit 1; }

aws ssm get-command-invocation --region "$REGION" --command-id "$CMD_ID" --instance-id "$ID" \
  --query StandardOutputContent --output text | sed "s/127.0.0.1/$IP/" > "$OUT"
chmod 600 "$OUT"
echo "saved $OUT"
echo "next:  export KUBECONFIG=$OUT && kubectl get nodes"
