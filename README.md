# Citus + Kubernetes — локальный распределённый кластер

Локальный кластер Kubernetes с развёрнутым Citus: координатор + 5 воркеров, шардирование и репликация шардов.

---

## Что сделано

- Поднят Kubernetes-кластер (Docker Desktop, kind) с 3 нодами
- Написан манифест `citus-config.yaml`: namespace, сервисы, StatefulSet координатора и 5 воркеров
- Настроен headless Service для адресации каждого воркера по DNS
- Зарегистрированы все 5 воркеров на координаторе через `citus_add_node`
- Включено шардирование: 32 шарда, фактор репликации 2

## Стек

- **Kubernetes** (Docker Desktop / kind)
- **Citus** `13.0.3` поверх PostgreSQL
- **kubectl**, **psql**

## Структура кластера

```
coordinator (1 pod)  ←  все клиентские запросы
    ↓ распределяет по шардам
worker-0 .. worker-4 (5 pods, 2 ноды)
```

Каждый шард хранится в 2 копиях на разных воркерах — потеря одного воркера не уничтожает данные.

## Ключевые команды

```bash
# Применить манифест
kubectl apply -f citus-config.yaml

# Статус подов
kubectl -n citus get pods -o wide

# Доступ к координатору
kubectl -n citus port-forward svc/citus-coordinator 55432:5432
psql "host=localhost port=55432 dbname=postgres user=postgres password=111"
```

```sql
-- Зарегистрировать воркеры
SELECT citus_add_node('citus-worker-0.citus-worker-headless.citus.svc.cluster.local', 5432);
-- ... повторить для worker-1..4

-- Включить шардирование
ALTER SYSTEM SET citus.shard_count = 32;
ALTER SYSTEM SET citus.shard_replication_factor = 2;
SELECT pg_reload_conf();

-- Создать distributed-таблицу
CREATE TABLE events (id bigserial, user_id bigint, payload text);
SELECT create_distributed_table('events', 'user_id');
```

## Что изучено

- Разница между нодой, подом, StatefulSet и Service в Kubernetes
- Зачем нужен headless Service для stateful-приложений
- Как Citus координирует запросы и раскладывает шарды по воркерам
- Чем `replicas: 5` в StatefulSet отличается от `shard_replication_factor`