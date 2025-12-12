#!/usr/bin/env bash
# Exit on error
set -o errexit

# Attempt to set the password. This might fail if already set, so we allow it to pass (|| true)
echo "Configuring Neo4j..."
./neo4j/bin/neo4j-admin dbms set-initial-password password || true

# Allow APOC
echo "dbms.security.procedures.unrestricted=apoc.*" >> neo4j/conf/neo4j.conf

echo "Starting Neo4j..."
./neo4j/bin/neo4j start

echo "Waiting for Neo4j to be ready..."
timeout=60
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

echo "Importing Data..."
# Copy data to import folder for easier access
cp data/save.csv neo4j/import/save.csv

# Run Cypher script
# We sed the script to replace the URL with the local file path
sed 's|https://media.githubusercontent.com/media/joopixel1/SportGraph/refs/heads/main/data/save.csv|file:///save.csv|g' script/soccer_neo4j_script.cypher > script/import_local.cypher

# Output the modified script for debugging
echo "--- Import Script ---"
head -n 25 script/import_local.cypher
echo "---------------------"

# Execute via cypher-shell
# Default user is neo4j, password is password from above
echo "password" | ./neo4j/bin/cypher-shell -u neo4j --password-from-stdin -f script/import_local.cypher

echo "Starting FastAPI..."
uvicorn api.src.main:app --host 0.0.0.0 --port $PORT
