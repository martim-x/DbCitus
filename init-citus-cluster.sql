-- пробросить порты
-- kubectl -n citus port-forward svc/citus-coordinator 55432:5432

SELECT citus_add_node('citus-worker-0.citus-worker-headless.citus.svc.cluster.local', 5432);
SELECT citus_add_node('citus-worker-1.citus-worker-headless.citus.svc.cluster.local', 5432);
SELECT citus_add_node('citus-worker-2.citus-worker-headless.citus.svc.cluster.local', 5432);
SELECT citus_add_node('citus-worker-3.citus-worker-headless.citus.svc.cluster.local', 5432);
SELECT citus_add_node('citus-worker-4.citus-worker-headless.citus.svc.cluster.local', 5432);

SELECT * FROM citus_get_active_worker_nodes();

SELECT version();
SELECT citus_version();


SELECT version();
SELECT citus_version();


-- тут 32
SHOW citus.shard_count;
-- по умолчанию 1
SHOW citus.shard_replication_factor;


ALTER SYSTEM SET citus.shard_count = 32;
ALTER SYSTEM SET citus.shard_replication_factor = 2;

SELECT pg_reload_conf();
