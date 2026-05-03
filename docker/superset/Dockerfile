FROM apache/superset:5.0.0

# Install psycopg2-binary — the base image ships without database drivers.
# ensurepip is needed first because the venv was built without pip.
USER root
RUN /app/.venv/bin/python3 -m ensurepip --upgrade --default-pip \
 && /app/.venv/bin/python3 -m pip install --quiet --no-cache-dir psycopg2-binary
