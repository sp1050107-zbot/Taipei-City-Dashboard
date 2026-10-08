-- dataset_info is written by every DE DAG (operators/common_pipeline.py upsert + utils/load_stage.py
-- update_lasttime_in_data_to_dataset_info) but no DDL for it ships in this repo or in the seed data, and the
-- etl task fails on its final step without it ("relation dataset_info does not exist").
-- Columns are exactly the ones those two code paths read/write; types are inferred, not copied from upstream.
-- Text columns because the upsert quotes every value, including Python None -> 'None'.
CREATE TABLE IF NOT EXISTS public.dataset_info (
    id                   text PRIMARY KEY,
    psql_table_name      text,
    name_cn              text,
    airflow_dag_id       text,
    mongo_collection     text,
    maintain_type        text,
    airflow_update_freq  text,
    source               text,
    source_type          text,
    source_department    text,
    lasttime_in_data     timestamptz,
    resource_updatetime  timestamptz,
    gis_format           text,
    coordinate           text,
    is_geometry          text,
    dataset_description  text,
    etl_description      text,
    been_used_count      integer DEFAULT 0,
    sensitivity          text,
    schedule_interval    text,
    _mtime               timestamptz DEFAULT CURRENT_TIMESTAMP
);
