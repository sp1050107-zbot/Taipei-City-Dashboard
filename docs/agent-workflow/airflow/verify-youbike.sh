#!/usr/bin/env bash
# Read-only check of the YouBike pipeline. Run from the integration checkout. Never prints credentials.
set -u
D="${DOCKER:-docker}"
psql_data() { "$D" exec postgres-data sh -c 'psql -U "$POSTGRES_USER" -d dashboard -tA' ; }

echo "== airflow container"; "$D" ps --filter name=dashboard-airflow --format '{{.Names}}  {{.Status}}'
echo "== TDX credentials present in container (names only)"
"$D" exec dashboard-airflow sh -c 'for v in CLIENT_ID CLIENT_SECRET; do eval "t=\${$v:-}"; [ -n "$t" ] && echo "$v: set (len ${#t})" || echo "$v: MISSING"; done'
echo "== DAG state"; "$D" exec dashboard-airflow airflow dags list 2>/dev/null | grep -E 'dag_id|R0051' || echo "R0051-3 not listed"
"$D" exec dashboard-airflow airflow dags list-import-errors 2>/dev/null | tail -5
echo "== tran_ubike_realtime (the table the dashboard chart reads)"
echo "select count(*) as rows, max(data_time) as newest_data_time, now() as now from tran_ubike_realtime" | psql_data
echo "== history table"; echo "select count(*) from tran_ubike_realtime_history" | psql_data 2>&1 | tail -1
echo "== chart as the dashboard sees it"; curl -s "http://localhost:8080/api/dev/component/60/chart?city=taipei" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'])"
