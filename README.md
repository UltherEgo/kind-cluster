[![End to End Tests](https://github.com/UltherEgo/kind-cluster/actions/workflows/end2end-tests.yml/badge.svg)](https://github.com/UltherEgo/kind-cluster/actions/workflows/end2end-tests.yml)
[![Hits](https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2FAndriyKalashnykov%2Fkind-cluster&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false)](https://hits.seeyoufarm.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
# kind-cluster
Create local Kubernetes clusters using Docker container "nodes" with [kind](https://kind.sigs.k8s.io/)


## Requirements

* [Docker](https://docs.docker.com/engine/install/)
* [kind](https://kind.sigs.k8s.io/docs/user/quick-start#installation)
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* [helm](https://helm.sh/docs/intro/install/)
* [curl](https://help.ubidots.com/en/articles/2165289-learn-how-to-install-run-curl-on-windows-macosx-linux)
* [jq](https://github.com/stedolan/jq/wiki/Installation)
* [base64](https://command-not-found.com/base64)

## Info

The complete cluster configuration is located in `k8s/kind-config.yaml`.

## Kind install

Documentation [kind](https://kind.sigs.k8s.io/docs/user/quick-start#installation)
```bash
# For AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

## Help

```bash
make help
```

```text
help                               - List available tasks
install-all                        - Install all (kind k8s cluster, Nginx ingress, MetaLB, demo workloads)
install-all-no-demo-workloads      - Install all (kind k8s cluster, Nginx ingress, MetaLB)
create-cluster                     - Create k8s cluster
export-cert                        - Export k8s keys(client) and certificates(client, cluster CA)
k8s-dashboard                      - Install k8s dashboard
nginx-ingress                      - Install Nginx ingress
metallb                            - Install MetalLB load balancer
deploy-app-nginx-ingress-localhost - Deploy httpd web server and create an ingress rule for a localhost (http://demo.localdev.me:80/), Patch ingress-nginx-controller service type -> LoadBlancer
deploy-app-helloweb                - Deploy helloweb
deploy-app-golang-hello-world-web  - Deploy golang-hello-world-web app
deploy-app-foo-bar-service         - Deploy foo-bar-service app
deploy-kube-prometheus-stack       - Deploy kube-prometheus-stack
delete-cluster                     - Delete K8s cluste
```

## Before use

Make sure you have all the necessary [requirements](https://github.com/UltherEgo/kind-cluster#requirements) installed

If you already have a kubeconfig, make a backup
```bash
[ -e ~/.kube/config ] && mv ~/.kube/config ~/.kube/config_bck
```

## Create kind k8s cluster, Nginx ingress, MetaLB

All operations can be performed using make, for example
```bash
make install-all-no-demo-workloads
```

## Install all (kind k8s cluster, Nginx ingress, MetaLB, demo workloads)


```bash
./scripts/kind-install-all.sh
```

Or you can install each component individually

## Create k8s cluster


```bash
./scripts/kind-create.sh
```

## Export k8s keys(client) and certificates(client, cluster CA)


```bash
./scripts/kind-create.sh
```

Script creates:
- client.key
- client.crt
- client.pfx
- cluster-ca.crt

## Install k8s dashboard

Install k8s dashboard


```bash
./scripts/kind-add-dashboard.sh
```

Script creates file with admin-user token
- dashboard-admin-token.txt

## Launch k8s Dashboard

v3.0.0-alpha0

```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard
kubectl apply -n kubernetes-dashboard -f ./k8s/dashboard-admin.yaml
export dashboard_admin_token=$(kubectl get secret -n kubernetes-dashboard admin-user-token -o jsonpath="{.data.token}" | base64 --decode)
echo "${dashboard_admin_token}" > dashboard-admin-token.txt
kubectl config set-credentials cluster-admin --token=${dashboard_admin_token}
echo "Dashboard Token: ${dashboard_admin_token}"

export POD_NAME=$(kubectl get pods -n kubernetes-dashboard -l "app.kubernetes.io/name=kubernetes-dashboard,app.kubernetes.io/instance=kubernetes-dashboard" -o jsonpath="{.items[0].metadata.name}")
kubectl -n kubernetes-dashboard port-forward $POD_NAME 8443:8443
xdg-open "https://localhost:8443"

# helm delete kubernetes-dashboard --namespace kubernetes-dashboard
# kubectl delete clusterrolebinding --ignore-not-found=true kubernetes-dashboard
# kubectl delete clusterrole --ignore-not-found=true kubernetes-dashboard
```

v2.x

```bash
# kill kubectl proxy if already running
pkill -9 -f "kubectl proxy"
# start new kubectl proxy
kubectl proxy –address=’0.0.0.0′ –accept-hosts=’^*$’ &
# copy admin-user token to the clipboard
cat ./dashboard-admin-token.txt | xclip -i
# open dashboard
xdg-open "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/" &
```

In Dashboard UI select "Token' and `Ctrl+V` 

## Install Nginx ingress


```bash
./scripts/kind-add-ingress-nginx.sh
```

## Install MetalLB load balancer


```bash
./scripts/kind-add-metallb.sh
```

## Deploy demo workloads

### Deploy httpd web server and create an ingress rule for a localhost `http://demo.localdev.me:80/`


```bash
./scripts/kind-deploy-app-nginx-ingress-localhost.sh
```

### Deploy helloweb


```bash
./scripts/kind-deploy-app-helloweb.sh
```

### Deploy golang-hello-world-web


```bash
./scripts/kind-deploy-app-golang-hello-world-web.sh
```

### Deploy foo-bar-service


```bash
./scripts/kind-deploy-app-foo-bar-service.sh
```

### Deploy Prometheus

Add prometheus and stable repo to local helm repository
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add stable https://charts.helm.sh/stable
helm repo update
```

Create namespace monitoring to deploy all services in that namespace
```bash
kubectl create namespace monitoring
```

Install kube-prometheus stack
```bash
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

kubectl apply -f prometheus-ingress.yaml -n monitoring
kubectl --namespace monitoring get pods -l release=kube-prometheus-stack
```

Delete kube-prometheus stack
```bash
kubectl delete -f ./k8s/prometheus.yaml
```

## Delete k8s cluster


```bash
./scripts/kind-delete.sh
```
