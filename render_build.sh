#!/usr/bin/env bash
# Exit on error
set -o errexit

echo "Installing Python dependencies..."
pip install -r requirements.txt

echo "Downloading Neo4j..."
# Download Neo4j Community 5.15.0
wget -qO neo4j.tar.gz "https://neo4j.com/artifact.php?name=neo4j-community-5.15.0-unix.tar.gz"

echo "Extracting Neo4j..."
tar -xf neo4j.tar.gz
mv neo4j-community-5.15.0 neo4j
rm neo4j.tar.gz

echo "Build complete."
