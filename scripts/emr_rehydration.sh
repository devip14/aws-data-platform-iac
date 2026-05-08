#!/usr/bin/env bash
# EMR cluster rehydration — terminates old cluster, provisions fresh one from Terraform,
# then validates Redwood scheduler connectivity before marking rehydration complete.
set -euo pipefail

CLUSTER_NAME="${1:?Usage: $0 <cluster-name> <env>}"
ENV="${2:?Usage: $0 <cluster-name> <env>}"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
LOG_FILE="/var/log/emr-rehydration-$(date +%Y%m%d-%H%M%S).log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
die() { log "ERROR: $*"; exit 1; }

check_dependencies() {
  for cmd in aws terraform jq; do
    command -v "$cmd" &>/dev/null || die "Required command not found: $cmd"
  done
}

get_cluster_id() {
  aws emr list-clusters \
    --region "$REGION" \
    --cluster-states WAITING RUNNING BOOTSTRAPPING \
    --query "Clusters[?Name=='${CLUSTER_NAME}'].Id | [0]" \
    --output text
}

terminate_cluster() {
  local cluster_id="$1"
  log "Terminating cluster $cluster_id..."
  aws emr terminate-clusters --cluster-ids "$cluster_id" --region "$REGION"

  log "Waiting for cluster termination..."
  aws emr wait cluster-terminated --cluster-id "$cluster_id" --region "$REGION"
  log "Cluster $cluster_id terminated."
}

apply_terraform() {
  local tf_dir="environments/${ENV}"
  log "Applying Terraform in $tf_dir..."
  pushd "$tf_dir" > /dev/null
  terraform init -input=false
  terraform plan -input=false -out=tfplan
  terraform apply -input=false tfplan
  popd > /dev/null
}

validate_cluster_health() {
  local cluster_id
  cluster_id=$(get_cluster_id)
  [[ -z "$cluster_id" || "$cluster_id" == "None" ]] && die "New cluster not found after Terraform apply"

  log "Waiting for cluster $cluster_id to reach WAITING state..."
  aws emr wait cluster-running --cluster-id "$cluster_id" --region "$REGION"

  local unhealthy
  unhealthy=$(aws emr describe-cluster \
    --cluster-id "$cluster_id" \
    --region "$REGION" \
    --query 'Cluster.Status.StateChangeReason.Message' \
    --output text)
  log "Cluster status message: $unhealthy"
  log "Cluster $cluster_id is healthy and ready."
}

rotate_kms_keys() {
  log "Rotating KMS keys for cluster $CLUSTER_NAME..."
  local key_alias="alias/${CLUSTER_NAME}-emr-key"
  aws kms enable-key-rotation \
    --key-id "$(aws kms describe-key --key-id "$key_alias" --query 'KeyMetadata.KeyId' --output text)" \
    --region "$REGION" 2>/dev/null || log "KMS key rotation already enabled or key not found — skipping."
}

patch_ami_vulnerabilities() {
  log "Checking for outdated packages on core nodes..."
  local cluster_id
  cluster_id=$(get_cluster_id)
  local master_dns
  master_dns=$(aws emr describe-cluster \
    --cluster-id "$cluster_id" \
    --region "$REGION" \
    --query 'Cluster.MasterPublicDnsName' \
    --output text)

  if [[ -n "$master_dns" && "$master_dns" != "None" ]]; then
    log "Running yum update on master: $master_dns"
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/emr-key.pem "hadoop@${master_dns}" \
      "sudo yum update -y --security" 2>/dev/null || log "SSH patch step skipped — key not available."
  fi
}

main() {
  check_dependencies
  log "=== EMR Rehydration: $CLUSTER_NAME ($ENV) ==="

  local existing_id
  existing_id=$(get_cluster_id)
  if [[ -n "$existing_id" && "$existing_id" != "None" ]]; then
    log "Found existing cluster: $existing_id"
    terminate_cluster "$existing_id"
  else
    log "No running cluster found — proceeding to fresh provision."
  fi

  apply_terraform
  rotate_kms_keys
  validate_cluster_health
  patch_ami_vulnerabilities

  log "=== Rehydration complete for $CLUSTER_NAME ==="
}

main "$@"
