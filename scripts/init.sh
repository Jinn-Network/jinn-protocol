#!/bin/bash
# Initialize the jinn-restore data directory
set -e

DATA_DIR="${JINN_DATA_DIR:-$HOME/.jinn-restore}"

mkdir -p "$DATA_DIR/artifacts"
mkdir -p "$DATA_DIR/measurements"
mkdir -p "$DATA_DIR/attempts"
mkdir -p "$DATA_DIR/blueprints"

echo "Initialized jinn-restore data directory at $DATA_DIR"
