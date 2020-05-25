kubectl create ns kubernetes-dashboard
helm install kubernetes-dashboard stable/kubernetes-dashboard \
  --set serviceAccount.create=true \
  --set serviceAccount.name=admin\
  --set rbac.clusterAdminRole=true \
  --namespace kubernetes-dashboard

helm del kubernetes-dashboard --namespace kubernetes-dashboard

kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get secret |  egrep -o "admin-token-\w" | awk '{print $1}') -o jsonpath="{.data.token}" | base64 --decode  


kubectl proxy --address='0.0.0.0' --port=8001 --accept-hosts='^*$'​


---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: k8s-dashboard
  namespace: kubernetes-dashboard
  annotations:
    nginx.ingress.kubernetes.io/secure-backends: "true"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  tls:
    - hosts:
      - k8sdash.dtux.lan
      secretName: tls-secret
  rules:
    - host: k8sdash.dtux.lan
      http:
        paths:
        - path: /
          backend:
            serviceName: kubernetes-dashboard
            servicePort: 443


apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: k8s-dashboard
  namespace: kubernetes-dashboard
  annotations:
    nginx.ingress.kubernetes.io/secure-backends: "true"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  rules:
  - http:
      paths:
      - path: /dashboard
        backend:
          serviceName: kubernetes-dashboard
          servicePort: 443s            