#citus #kubernetes
___
## Кластер


```bash
kubectl config current-context
kubectl config get-contexts
kubectl get nodes
kubectl get ns
```

```bash
# ноды с ролями и ресурсами
kubectl describe nodes
```


___
## Namespace и манифест


```bash
# применить / удалить все ресурсы
kubectl apply -f citus-config.yaml
kubectl delete -f citus-config.yaml
```

```bash
# проверить события по namespace
kubectl -n citus get events --sort-by=.lastTimestamp
```


___
## Поды и сервисы


```bash
# поды с нодами, IP и статусом
kubectl -n citus get pods -o wide

# сервисы (координатор + headless-воркеры)
kubectl -n citus get svc
```

```bash
# посмотреть endpoints headless-сервиса воркеров
kubectl -n citus get endpoints citus-worker-headless -o wide
```


___
## Отладка


```bash
kubectl -n citus logs citus-coordinator-0
kubectl -n citus logs citus-worker-0

# детальная инфа + события
kubectl -n citus describe pod citus-worker-0
```

```bash
# выполнить команду внутри pod'а
kubectl -n citus exec -it citus-coordinator-0 -- bash
kubectl -n citus exec -it citus-worker-0 -- psql -U postgres
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

```sql
-- проверить версию и расширение citus
show server_version;
select * from pg_extension where extname = 'citus';
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
nslookup citus-worker-headless
```

```bash
# проверить, что имена воркеров резолвятся в разные IP
ping -c 1 citus-worker-0.citus-worker-headless
ping -c 1 citus-worker-1.citus-worker-headless
```


___
## Citus: регистрация нод и шардирование


```sql
-- зарегистрировать воркеров
select citus_add_node('citus-worker-0.citus-worker-headless.citus.svc.cluster.local', 5432);
select citus_add_node('citus-worker-1.citus-worker-headless.citus.svc.cluster.local', 5432);
select citus_add_node('citus-worker-2.citus-worker-headless.citus.svc.cluster.local', 5432);
select citus_add_node('citus-worker-3.citus-worker-headless.citus.svc.cluster.local', 5432);
select citus_add_node('citus-worker-4.citus-worker-headless.citus.svc.cluster.local', 5432);

-- активные воркеры
select * from master_get_active_worker_nodes();
```

```sql
-- политика шардирования и репликации
alter system set citus.shard_count = 32;
alter system set citus.shard_replication_factor = 2;
select pg_reload_conf();

-- создать distributed-таблицу
create table events (
    id       bigserial primary key,
    user_id  bigint not null,
    payload  text
);
select create_distributed_table('events', 'user_id');
```

```sql
-- проверить, что шарды разложились
select
    s.shardid,
    n.nodename,
    n.nodeport
from pg_dist_shard s
join pg_dist_placement p on s.shardid = p.shardid
join pg_dist_node n      on p.groupid = n.groupid
where s.logicalrelid = 'events'::regclass
order by s.shardid, n.nodename;
```


___
## Логическая репликация: базовые команды


```sql
-- включить logical wal и слоты
alter system set wal_level = 'logical';
alter system set max_replication_slots = 10;
alter system set max_wal_senders      = 10;

-- роль репликатора
create role repl_user with login replication password '111';
```

```sql
-- publication на coord_1
create table app_users(
    id      uuid primary key default gen_random_uuid(),
    name    varchar,
    balance numeric
);

create publication coord1_pub_app
for table app_users;
```

```sql
-- subscription на coord_2
create table app_users(
    id      uuid primary key default gen_random_uuid(),
    name    varchar,
    balance numeric
);

create subscription coord2_sub_from_coord1
connection 'host=citus-coordinator-1.citus port=5432 dbname=postgres user=repl_user password=111'
publication coord1_pub_app;
```

```sql
-- статус подписок
select * from pg_subscription;
select * from pg_stat_subscription;
```