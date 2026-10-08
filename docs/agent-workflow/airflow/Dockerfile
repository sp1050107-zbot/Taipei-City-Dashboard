# Minimal Airflow image for running only the YouBike DAG(s) locally.
# The upstream DE image (Taipei-City-Dashboard-DE/docker/develop/Dockerfile) installs gdal + build tools and
# the full requirements.txt; this one installs only what `utils/extract_stage.py` and `utils/load_stage.py`
# import at module level (geopandas, fiona, geoalchemy2). Installed under Airflow's constraints file so the
# pinned pandas/sqlalchemy versions are not disturbed.
# fiona has no aarch64 wheel on PyPI (checked for 1.10.1, py3.12), so it is compiled against the system GDAL.
FROM apache/airflow:2.10.5

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends gdal-bin libgdal-dev build-essential \
 && apt-get clean && rm -rf /var/lib/apt/lists/*
USER airflow

RUN pip install --no-cache-dir \
      --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-2.10.5/constraints-3.12.txt" \
      geopandas==1.1.1 GeoAlchemy2==0.14.7 fiona

# Created here (owned by the airflow user) so named volumes mounted on them are writable.
RUN mkdir -p /opt/airflow/state /opt/airflow/data
