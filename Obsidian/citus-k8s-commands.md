#citus #kubernetes
___
## Кластер

```bash
kubectl config current-context
kubectl config get-contexts
kubectl get nodes
kubectl get ns
```


___
## Namespace и манифест

```bash
# применить / удалить все ресурсы
kubectl apply -f citus-config.yaml
kubectl delete -f citus-config.yaml
```


___
## Поды и сервисы

```bash
# поды с нодами, IP и статусом
kubectl -n citus get pods -o wide

# сервисы (координатор + headless-воркеры)
kubectl -n citus get svc
```


___
## Отладка

```bash
kubectl -n citus logs citus-coordinator-0
kubectl -n citus logs citus-worker-0

# детальная инфа + события
kubectl -n citus describe pod citus-worker-0
```


___
## Подключение к координатору

```bash
# пробросить порт координатора на хост
kubectl -n citus port-forward svc/citus-coordinator 55432:5432
```

```bash
psql "host=localhost port=55432 dbname=postgres user=postgres password=111"
```


___
## DNS (проверка внутри кластера)

```bash
kubectl -n citus run dns-test --image=busybox:1.36 --restart=Never -it -- sh
```

```bash
# внутри dns-test
nslookup citus-worker-0.citus-worker-headless
nslookup citus-coordinator
```