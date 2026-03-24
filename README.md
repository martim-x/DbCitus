#locker #postgresql #citus #kubernetes #replication
___
## О проекте

Изучение Kubernetes, PostgreSQL, Citus и логической репликации: развёртывание кластера, настройка шардирования, двунаправленной репликации между координаторами и глобального лок‑сервиса pg-locker для безопасного мультимастера.


Стек: PostgreSQL 18, Citus, Kubernetes (kind / Docker Desktop).


___
## Архитектура кластера


Citus-кластер в Kubernetes: два координатора + 5 воркеров (32 шарда, `shard_replication_factor = 2`).

#kubernetes
### Координаторы


- Оба координатора в режиме мультимастера — двунаправленная логическая репликация через `origin = none` (Postgres 18).
- Петли исключены: подписка с `origin = none` игнорирует уже реплицированные изменения.
- Для репликации используется `CREATE PUBLICATION` / `CREATE SUBSCRIPTION` на обеих сторонах.


### Воркеры


- Шардированные таблицы (`events` и др.) распределяются по воркерам через `create_distributed_table`.
- Таблицы с триггерами (например, те, что используют `pg-locker`) **специально не шардируются**, потому что Citus не поддерживает обычные триггеры на distributed-таблицах.


#locker
### pg-locker


Отдельный сервис-локер (`locker.locks`) с функциями `try_lock` / `release_lock`:

- хранит глобальные блокировки по `(table_name, key_text, coord_id)`;
- вызывается из координаторов через `dblink_exec` в триггерах `BEFORE/AFTER` на DML;
- гарантирует: одна строка (по ключу) не обновляется одновременно с двух координаторов при двунаправленной репликации.


___
## Логическая репликация и мультимастер


#replication
- Односторонняя схема: `CREATE PUBLICATION` на первом координаторе, `CREATE SUBSCRIPTION` на втором, initial copy + постоянный стрим WAL.
- Двунаправленная схема: две публикации (по одной на координатор), две подписки с `WITH (origin = none, copy_data = false)` после initial sync. Это даёт мультимастер без петель.
- Конфликты параллельных обновлений одной строки решаются за счёт `pg-locker` — второй координатор просто не получает глобальный лок и транзакция падает.


___
## Схема БД


Предметная область — автосервис / рассрочка:

- Пользователи: `app_user`, `app_user_profile`, `app_role`
- Справочники: `brand`, `drive_type`, `transmission_type`, `capacity`
- Автомобили: `car`, `car_passport`, `car_image`, `car_service_history`
- Избранное: `user_favorite_car`
- Заявки и заказы: `app_request` → `app_order`

Жизненный цикл: пользователь создаёт заявку (`app_request`), менеджер принимает и оформляет заказ (`app_order`).

Весь доступ к данным — **только через хранимые функции/процедуры**.

Роли БД: `guest`, `user`, `manager`, `admin`.


___
## Производительность и шардирование


#citus
- Для больших таблиц (например, `events`) включено шардирование: `citus.shard_count = 32`, `citus.shard_replication_factor = 2`.
- `create_distributed_table` автоматически создаёт шарды и раскладывает их по воркерам; репликация шардов обеспечивает отказоустойчивость по воркерам.
- Таблицы с триггерами и сложной логикой оставляются локальными на координаторах и масштабируются через логическую репликацию, а не через Citus.
- Нагрузочный тест: ≥ 100 000 строк в `app_request`, анализ планов через `EXPLAIN ANALYZE`.


___
## Запуск и проверка


#kubernetes
```bash
kubectl apply -f citus-config.yaml
kubectl -n citus get pods -o wide
kubectl -n citus port-forward svc/citus-coordinator 55432:5432
psql "host=localhost port=55432 dbname=postgres user=postgres password=111"
```

```sql
-- проверить воркеров
select * from master_get_active_worker_nodes();

-- проверить, что таблица зашардирована
select * from pg_dist_shard where logicalrelid = 'events'::regclass;

-- проверить статусы подписок
select * from pg_subscription;
select * from pg_stat_subscription;
```