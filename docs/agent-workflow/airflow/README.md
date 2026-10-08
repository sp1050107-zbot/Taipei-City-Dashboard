# Local YouBike pipeline (Airflow, single container)

Makes the dashboard's **YouBike chart** (`在站車輛`, component 60) read live data instead of the seed snapshot
(newest row 2025-02-19). The **map layer is not affected**: `youbike_realtime` is a static file,
`Taipei-City-Dashboard-FE/public/mapData/youbike_realtime.geojson`, read by the browser without touching the DB.

Scope: only DAG `proj_city_dashboard_R0051-3` (Taipei, every 10 min, TDX -> `tran_ubike_realtime` + `tran_ubike_realtime_history`).
SQLite + SequentialExecutor, scheduler only (no web UI); use `docker exec dashboard-airflow airflow ...`.

## Prerequisites
- Phase 1 stack running (`br_dashboard` network, `postgres-data`).
- `~/Taipei-City-Dashboard/tdx-key.txt`, mode 600, git-ignored, two lines: `CLIENT_ID=...` / `CLIENT_SECRET=...`.
  Credentials come from https://tdx.transportdata.tw/user/dataservice/key (API key, not the MQTT one).

## Back up first (the first successful run truncates `tran_ubike_realtime`)
    docker exec postgres-data sh -c 'pg_dump -U "$POSTGRES_USER" -d dashboard -t tran_ubike_realtime' > ~/tran_ubike_realtime.seed.sql

## One-time: create `dataset_info` (the seed data does not ship it; without it the etl task fails on its last step)
    docker exec -i postgres-data sh -c 'psql -U "$POSTGRES_USER" -d dashboard -v ON_ERROR_STOP=1' < docs/agent-workflow/airflow/dataset_info.sql

## Start / stop (integration checkout only)
    docker compose --env-file docker/.env -f docs/agent-workflow/airflow/docker-compose.airflow.yaml up -d --build
    docker exec dashboard-airflow airflow dags unpause proj_city_dashboard_R0051-3
    docker exec dashboard-airflow airflow dags trigger proj_city_dashboard_R0051-3
    docs/agent-workflow/airflow/verify-youbike.sh
    docker compose -f docs/agent-workflow/airflow/docker-compose.airflow.yaml down      # volumes kept

## Roll back to the seed snapshot
    docker compose -f docs/agent-workflow/airflow/docker-compose.airflow.yaml down
    docker exec -i postgres-data sh -c 'psql -U "$POSTGRES_USER" -d dashboard -c "truncate tran_ubike_realtime"'
    docker exec -i postgres-data sh -c 'psql -U "$POSTGRES_USER" -d dashboard' < ~/tran_ubike_realtime.seed.sql

## Observed on first run (2026-10-08)
- TDX auth + fetch + load worked: `tran_ubike_realtime` went from 1528 rows (newest 2025-02-19) to 1813 rows (newest = now).
- Container memory about 330 MiB (limit 2 GiB). Image 3.65 GB (fiona compiled against system GDAL; no aarch64 wheel).
- `dataset_info.lasttime_in_data` stays empty: the DAG updates `WHERE airflow_dag_id = 'R0051-3'` but the row is stored as
  `proj_city_dashboard_R0051-3`. Upstream quirk, cosmetic, left as is.
