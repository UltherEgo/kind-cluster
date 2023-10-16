#!/bin/bash

# set -x
LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

TIMEOUT=${1:-180s}

if [ -z "$TIMEOUT" ]; then
    echo "Provide deployment timeout"
    exit 1
fi

cd $SCRIPT_PARENT_DIR
echo "Deploy kube-prometheus-stack"

## Create Namespace
echo "Create namespace monitoring"
kubectl create namespace monitoring

## Deploy kube-prometheus-stack
echo "Helm install kube-prometheus-stack"
helm install --wait --timeout 15m \
   --namespace monitoring --create-namespace \
   --repo https://prometheus-community.github.io/helm-charts \
   kube-prometheus-stack kube-prometheus-stack --values - <<EOF 
 kubeEtcd:
   service:
     targetPort: 2381
 kubeControllerManager:  
   service:
     targetPort: 10257
 kubeScheduler:
   service:
     targetPort: 10259
EOF

## Deploy Ingress for Grafana, Prometheus, Alertmanager
echo "Set ingress with loadbalancer to localhost"
kubectl apply -f k8s/prometheus-ingress.yaml -n monitoring

## Permission
echo -e "Permission \nLogin: admin \nPassword: prom-operator"