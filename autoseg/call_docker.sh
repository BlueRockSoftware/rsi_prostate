#!/bin/sh
# Calls Docker container for segmenting prostate from T2 volume
#
# Supports two authentication methods:
# 1. DOCKER_CONFIG_JSON - JSON config string (preferred for Kubernetes)
# 2. GHCR_LOGIN - Password for docker login (legacy)

set -e

path_seg_dir=$1  # Path to directory where segmentation output will be saved

if [ -z "$path_seg_dir" ]; then
    echo "ERROR: No segmentation directory provided"
    exit 1
fi

# Set up Docker authentication
if [ -n "$DOCKER_CONFIG_JSON" ]; then
    # Use DOCKER_CONFIG_JSON (Kubernetes secret method)
    DOCKER_CONFIG_DIR="/tmp/.docker"
    mkdir -p "$DOCKER_CONFIG_DIR"
    echo "$DOCKER_CONFIG_JSON" > "$DOCKER_CONFIG_DIR/config.json"
    export DOCKER_CONFIG="$DOCKER_CONFIG_DIR"
    echo "Docker config written to $DOCKER_CONFIG_DIR/config.json"
elif [ -n "$GHCR_LOGIN" ]; then
    # Legacy: Use GHCR_LOGIN for docker login
    echo "$GHCR_LOGIN" | docker login ghcr.io -u "${GHCR_USERNAME:-stephen-bluerocksoft}" --password-stdin
fi

# Mirror contents from path_seg_dir (main container) to shared-volume (sidecar container)
# Use --no-group --no-owner to avoid permission errors on shared volumes
echo "Syncing input files to shared volume..."
rsync -avq --delete --no-group --no-owner "$path_seg_dir/" /shared-volume/

# Run the prostate segmentation container
echo "Running prostate segmentation container..."
echo "docker run -i --rm -u 0:0 -v /shared-volume:/input -v /shared-volume:/output ghcr.io/precision-health/prostate-segmentation:dev"
docker run -i --rm -u 0:0 -v /shared-volume:/input -v /shared-volume:/output ghcr.io/precision-health/prostate-segmentation:dev

# After the job finishes, sync back the results from shared-volume to path_seg_dir
echo "Syncing results back from shared volume..."
rsync -avq --delete --no-group --no-owner /shared-volume/ "$path_seg_dir/"

echo "Prostate segmentation completed successfully"
