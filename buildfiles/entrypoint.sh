#!/bin/bash
set -e

echo "Running database migrations..."
cd /mlflow
alembic upgrade head

echo "Starting MLflow server..."
exec "$@"
