Container Expert
----------------------------

Treinamento Descomplicando o Docker
Data início • 28 de março
Calendário • 28/03, 04/04, 11/04, 18/04 (aulas já liberadas na plataforma) e 25/04


Criando ambiente de estudo
----------------------------


- Cria todas as maquinas do grupo master
  
```bash

 ./create_kvm.sh n masters

```


- Cria todas as maquinas do grupo Workers
  
```bash

 ./create_kvm.sh n masters

```

- Aguarde por 5 minutos para terminar o upgrade das vms

- Instala as dependencias e configura docker em todas as maquinas


```bash

ansible-playbook -i inventories/hosts playbook.yml 

```

# Docker Swarm Visualizer
*** note ***
_This only works with Docker Swarm Mode in Docker Engine 1.12.0 and later. It does not work with the separate Docker Swarm project_

To run with a different context root (useful when running behind an external load balancer):

```bash
$ docker run -it -d -e CTX_ROOT=/visualizer -v /var/run/docker.sock:/var/run/docker.sock dockersamples/visualizer
```

To run in a docker swarm:

```
$ docker service create \
  --name=viz \
  --publish=8080:8080/tcp \
  --constraint=node.role==manager \
  --mount=type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  dockersamples/visualizer
```
