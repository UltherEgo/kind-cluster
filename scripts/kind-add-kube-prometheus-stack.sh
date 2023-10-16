#!/bin/bash

# set -x
LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

cd $SCRIPT_PARENT_DIR

# https://medium.com/@charled.breteche/kind-fix-missing-prometheus-operator-targets-1a1ff5d8c8ad

helm upgrade --install --wait --timeout 15m \
  --namespace monitoring --create-namespace \
  --repo https://prometheus-community.github.io/helm-charts \
  kube-prometheus-stack kube-prometheus-stack --values - <<EOF
kubeEtcd:
  service:
    targetPort: 2381
EOF

echo $SCRIPT_PARENT_DIR
echo "Add Ingress kube-prometheus-stack"
kubectl apply -f k8s/prometheus-ingress.yaml -n monitoring

kubectl --namespace monitoring get pods -l "release=kube-prometheus-stack"

echo "changing kube-prometheus-stack-grafana service type to LoadBlancer"
kubectl patch svc kube-prometheus-stack-grafana -n monitoring --type='json' -p "[{\"op\":\"replace\",\"path\":\"/spec/type\",\"value\":\"LoadBalancer\"}]"

echo "waiting for golang-hello-world-web service to get External-IP"
until kubectl get service/kube-prometheus-stack-grafana -n monitoring --output=jsonpath='{.status.loadBalancer}' | grep "ingress"; do : ; done &&

# User: admin
# Pwd:  prom-operator
echo "---------------------------"
echo -n "Grafana User: " && kubectl get secret kube-prometheus-stack-grafana -n monitoring -o jsonpath="{.data.admin-user}" | base64 --decode ; echo 
echo -n "Grafana Pwd:  " && kubectl get secret kube-prometheus-stack-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
echo "---------------------------"

service_ip=$(kubectl get services kube-prometheus-stack-grafana -n monitoring -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
ingress_grafana=$(kubectl get ingress prometheus-me -n monitoring -o jsonpath='{.spec.rules[0].host}')
ingress_prometheus=$(kubectl get ingress grafana-me -n monitoring -o jsonpath='{.spec.rules[0].host}')
ingress_alertmanager=$(kubectl get ingress alertmanager-me -n monitoring -o jsonpath='{.spec.rules[0].host}')
echo "Grafana Service: http://${service_ip}:80/"
echo "Grafana URL: http://${ingress_grafana}"
echo "Prometheus URL: http://${ingress_prometheus}"
echo "Alertmanager URL: http://${ingress_alertmanager}"
# xdg-open  ${service_ip}:80/

# kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# xdg-open http://localhost:9090/targets

cd $LAUNCH_DIR