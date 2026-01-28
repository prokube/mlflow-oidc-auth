#!/bin/bash
set -e

# Get the repository root and buildfiles directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Generate timestamp tag
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
IMAGE_NAME="${IMAGE_NAME:-mlflow-oidc-auth}"
IMAGE_TAG="${IMAGE_TAG:-$TIMESTAMP}"

echo "Repository root: $REPO_ROOT"
echo "Build directory: $BUILD_DIR"
echo "Building: $IMAGE_NAME:$IMAGE_TAG"

# Change to buildfiles directory for docker build context
cd "$BUILD_DIR"

# Copy mlflow-oidc-auth source into the build context
echo "Copying source files..."
cp -r "$REPO_ROOT/mlflow_oidc_auth" .
cp -r "$REPO_ROOT/web-react" .
cp "$REPO_ROOT/pyproject.toml" mlflow_oidc_auth_pyproject.toml
mkdir -p buildfiles
cp "$BUILD_DIR/entrypoint.sh" buildfiles/

# Build the Docker image
echo "Building Docker image..."
docker build --platform linux/amd64 \
  -t "$IMAGE_NAME:$IMAGE_TAG" \
  -t "$IMAGE_NAME:latest" \
  .

# Clean up
echo "Cleaning up build artifacts..."
rm -rf mlflow_oidc_auth
rm -rf web-react
rm -rf buildfiles
rm -f mlflow_oidc_auth_pyproject.toml

echo ""
echo "Build complete!"
echo "  $IMAGE_NAME:$IMAGE_TAG"
echo "  $IMAGE_NAME:latest"
echo ""
echo "To run the image:"
echo "  docker run -p 5000:5000 $IMAGE_NAME:$IMAGE_TAG"
