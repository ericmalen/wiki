#!/bin/bash

# Enable strict error handling
set -euo pipefail

# Function to handle errors
function handle_error {
  echo "Error on line $1"
  exit 1
}
trap 'handle_error $LINENO' ERR

ZONE="northamerica-northeast1-a"
CLUSTER_NAME="gke-cluster"
VPC_NETWORK="gke-vpc"

# Enable required APIs
echo "Enabling required APIs"
gcloud services enable compute.googleapis.com container.googleapis.com

# Create VPC network
echo "Creating VPC network: $VPC_NETWORK"
gcloud compute networks create "$VPC_NETWORK" --subnet-mode=auto

# Create GKE cluster
echo "Creating GKE cluster: $CLUSTER_NAME in zone: $ZONE"
gcloud container clusters create "$CLUSTER_NAME" \
    --zone "$ZONE" \
    --network "$VPC_NETWORK" \
    --num-nodes "1"

# Get cluster credentials
echo "Getting cluster credentials for: $CLUSTER_NAME"
gcloud container clusters get-credentials "$CLUSTER_NAME" --zone "$ZONE"

# Deploy 'Hello World' application
echo "Deploying 'Hello World' application..."
kubectl create deployment hello-world --image=gcr.io/google-samples/hello-app:1.0

# Expose deployment via LoadBalancer
echo "Exposing deployment 'hello-world' via LoadBalancer..."
kubectl expose deployment hello-world --type=LoadBalancer --port 80 --target-port 8080

# Wait for External IP
echo "Waiting for External IP..."
while true; do
  EXTERNAL_IP=$(kubectl get service hello-world --output jsonpath='{.status.loadBalancer.ingress[0].ip}' || true)
  if [ -n "$EXTERNAL_IP" ]; then
    break
  fi
  echo "Waiting for external IP..."
  sleep 10
done

echo "Application is available at http://$EXTERNAL_IP"

echo "Setup complete."