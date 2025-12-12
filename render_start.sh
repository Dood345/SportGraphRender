#!/usr/bin/env bash
# Exit on error
set -o errexit

# Attempt to set the password. This might fail if already set, so we allow it to pass (|| true)
echo "Configuring Neo4j..."
./neo4j/bin/neo4j-admin dbms set-initial-password password || true

echo "Starting Neo4j..."
./neo4j/bin/neo4j start

echo "Waiting for Neo4j to be ready..."
# Loop wait until port 7687 is open. 
# Note: Render Linux environment usually supports /dev/tcp
timeout=30
while ! (echo > /dev/tcp/localhost/7687) >/dev/null 2>&1; do
    if [ $timeout -le 0 ]; then
        echo "Timed out waiting for Neo4j"
        exit 1
    fi
    echo "Waiting for port 7687..."
    sleep 2
    timeout=$((timeout - 2))
done
echo "Neo4j is operational."

echo "Starting FastAPI..."
uvicorn api.src.main:app --host 0.0.0.0 --port $PORT
