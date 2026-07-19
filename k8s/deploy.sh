#!/bin/bash
# WHY a script instead of plain `kubectl apply -f k8s/base/`:
# These manifests need real values (ACR login server, Key Vault URI, etc.)
# that only exist after `terraform apply` — envsubst fills in the
# ${VARS} in each YAML file from your actual Terraform outputs before
# applying. This is a lightweight stand-in for what a templating tool
# (Helm) or overlay tool (Kustomize) would normally do — worth knowing
# this script is a manual version of a problem those tools solve properly
# at scale.
#
# WHY explicit apply ORDER matters: ServiceAccount and ConfigMap must
# exist before the Job/Deployment that reference them. The migration Job
# must complete before the Deployment starts — same dependency reasoning
# as docker-compose's `depends_on: migrate: condition:
# service_completed_successfully` in Stage 3, just expressed with
# `kubectl wait` instead of Compose's built-in mechanism.

set -e
cd "$(dirname "$0")"   # k8s/ directory

echo "Reading values from Terraform outputs..."
export APP_IDENTITY_CLIENT_ID=$(cd ../terraform && terraform output -raw app_identity_client_id)
export KEY_VAULT_URI=$(cd ../terraform && terraform output -raw key_vault_uri)
export POSTGRES_HOST=$(cd ../terraform && terraform output -raw postgres_fqdn)
export POSTGRES_USER=$(cd ../terraform && terraform output -raw postgres_admin_username)
export POSTGRES_DB=$(cd ../terraform && terraform output -raw postgres_db_name)
export ACR_LOGIN_SERVER=$(cd ../terraform && terraform output -raw acr_login_server)

echo "Applying ServiceAccount..."
envsubst < base/serviceaccount.yaml | kubectl apply -f -

echo "Applying ConfigMap..."
envsubst < base/configmap.yaml | kubectl apply -f -

echo "Running migration Job..."
kubectl delete job backend-app-migrate --ignore-not-found
envsubst < base/migration-job.yaml | kubectl apply -f -
echo "Waiting for migration to complete..."
kubectl wait --for=condition=complete job/backend-app-migrate --timeout=180s

echo "Applying Deployment + Service..."
envsubst < base/deployment.yaml | kubectl apply -f -
envsubst < base/service.yaml | kubectl apply -f -

echo ""
echo "Done. Check status with:"
echo "  kubectl get pods,svc,jobs"
