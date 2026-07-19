#!/bin/bash
# WHY this is a SEPARATE script from deploy.sh:
# Installing the ingress controller is a one-time, CLUSTER-LEVEL setup
# step (like installing a piece of infrastructure), fundamentally
# different from deploying/redeploying YOUR app. Re-running this script
# is safe (Helm upgrades in place if already installed), but it's not
# something that needs to happen on every app deploy the way deploy.sh
# does.

set -e
cd "$(dirname "$0")"

if ! command -v helm &> /dev/null; then
  echo "Helm not found — installing..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "Installing/upgrading ingress-nginx controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --wait --timeout 5m

echo ""
echo "Waiting for the controller to get a public IP from Azure (this creates a real Load Balancer + public IP — takes a minute)..."
kubectl wait --namespace ingress-nginx \
  --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' \
  service/ingress-nginx-controller \
  --timeout=180s

EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress controller public IP: $EXTERNAL_IP"

echo ""
echo "Creating/updating TLS secret from the self-signed cert (same one from Stage 3)..."
if [ ! -f ../nginx/certs/localhost.crt ]; then
  echo "No cert found — generating one now..."
  (cd ../nginx && ./generate-certs.sh)
fi

kubectl create secret tls backend-app-tls \
  --cert=../nginx/certs/localhost.crt \
  --key=../nginx/certs/localhost.key \
  --namespace default \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Applying Ingress resource..."
kubectl apply -f base/ingress.yaml

echo ""
echo "Done. Test with:"
echo "  curl -k https://$EXTERNAL_IP/items"
