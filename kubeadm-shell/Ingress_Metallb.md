
# metallb

_METALLB_VERSION="v0.9.3" 

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/${_METALLB_VERSION}/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/${_METALLB_VERSION}/manifests/metallb.yaml
# On first install only
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
 

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 10.1.2.53-10.1.2.100
EOF

kubectl get pods,serviceaccounts,daemonsets,deployments,roles,rolebindings -n metallb-system
kubetail -l component=speaker -n metallb-system

## Ingress 
 kubectl -n ingress-nginx get svc


 helm install ingress-nginx-deploy ingress-nginx/ingress-nginx
kubectl create ns ingress-nginx

 helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --set rbac.create=true \
    --set controller.replicaCount=2 \
    --set controller.publishService.enabled=true \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set controller.service.type="LoadBalancer" \
    --set controller.service.externalIPs[0]="192.168.2.50" \
    --set controller.service.loadBalancerIP="192.168.2.50" \
    --set controller.metrics.enabled=true  

POD_NAME=$(kubectl get pods  --namespace ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}')
kubectl --namespace ingress-nginx exec -it $POD_NAME -- /nginx-ingress-controller --version

kubectl describe service ingress-nginx-controller -n ingress-nginx

curl -L -k http://192.168.2.50/test

    helm delete ingress-nginx  -n ingress-nginx