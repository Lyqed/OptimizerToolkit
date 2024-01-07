#!/bin/bash

# Function to fetch and display Docker image versions
fetch_versions() {
    local image=$1
    local max=$2
    curl -s "https://registry.hub.docker.com/v2/repositories/library/$image/tags/" | jq -r '.results[].name' | head -n $max
}

# Default maximum number of versions to show
MAX_VERSIONS=10

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--versions) VERSIONS_FLAG=true ;;
        -m|--max) MAX_VERSIONS="$2"; shift ;;
        *) IMAGE="$1" ;;
    esac
    shift
done

# Check if image name is provided
if [ -z "$IMAGE" ]; then
    echo "No image name provided. Usage: dockerx [image] [-v/--versions] [-m/--max <number>]"
    exit 1
fi

# Fetch and display versions if requested
if [ "$VERSIONS_FLAG" = true ]; then
    fetch_versions "$IMAGE" "$MAX_VERSIONS"
else
    echo "Invalid usage. Use -v/--versions to see available versions."
fi

