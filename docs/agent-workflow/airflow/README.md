# Local YouBike pipeline (Airflow, single container)

Makes the dashboard's **YouBike chart** (`在站車輛`, component 60) read live data instead of the seed snapshot
(newest row 2025-02-19). The **map layer is not affected**: `youbike_realtime` is a static file,
`Taipei-City-Dashboard-FE/public/mapData/youbike_realtime.geojson`, read by the browser without touching the DB.

Scope: only DAG `R0051-3` (Taipei, every 10 min, TDX -> `tran_ubike_realtime` + `tran_ubike_realtime_history`).
SQLite + SequentialExecutor, scheduler only (no web UI); use `docker exec dashboard-airflow airflow ...`.

## Prerequisites
- Phase 1 stack running (`br_dashboard` network, `postgres-data`).
- `~/Taipei-City-Dashboard/tdx-key.txt`, mode 600, git-ignored, two lines: `CLIENT_ID=...` / `CLIENT_SECRET=...`.
  Credentials come from https://tdx.transportdata.tw/user/dataservice/key (API key, not the MQTT one).

## Back up first (the first successful run truncates `tran_ubike_realtime`)
    docker exec postgres-data sh -c 'pg_dump -U "$POSTGRES_USER" -d dashboard -t tran_ubike_realtime' > ~/tran_ubike_realtime.seed.sql

## Start / stop (integration checkout only)
    docker compose --env-file docker/.env -f docs/agent-workflow/airflow/docker-compose.airflow.yaml up -d --build
    docker exec dashboard-airflow airflow dags unpause R0051-3
    docker exec dashboard-airflow airflow dags trigger R0051-3
    docs/agent-workflow/airflow/verify-youbike.sh
    docker compose -f docs/agent-workflow/airflow/docker-compose.airflow.yaml down      # volumes kept

## Roll back to the seed snapshot
    docker compose -f docs/agent-workflow/airflow/docker-compose.airflow.yaml down
    docker exec -i postgres-data sh -c 'psql -U "$POSTGRES_USER" -d dashboard -c "truncate tran_ubike_realtime"'
    docker exec -i postgres-data sh -c 'psql -U "$POSTGRES_USER" -d dashboard' < ~/tran_ubike_realtime.seed.sql
