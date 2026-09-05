# Build Files

Docker build configuration for the prokube mlflow-oidc-auth image.

## Why Custom Dockerfile?

The upstream [mlflow-tracking-server-docker](https://github.com/mlflow-oidc/mlflow-tracking-server-docker) expects mlflow-oidc-auth to be available on PyPI.

We need these modifications to build directly from source (without PyPI package):
- Install Node.js/Yarn to build the React UI from source
- Copy and install local mlflow-oidc-auth code
- Build and bundle the UI into the package

## Files

- **Dockerfile**: Modified version of upstream Dockerfile
  - Added Node.js/Yarn installation
  - Added React UI build steps
  - Installs mlflow-oidc-auth from local source

- **pyproject.toml & uv.lock**: From upstream https://github.com/mlflow-oidc/mlflow-tracking-server-docker
  - Defines MLflow version + cloud storage dependencies
  - Update by copying from upstream when needed

- **build-locally.sh**: Standalone build script
  - Copies source files into build context
  - Runs docker build
  - Cleans up afterwards

## Versions

- MLflow 3.16.0
- mlflow-oidc-auth 7.18.1 source

The previous prokube authorization and user-deletion fixes are now implemented
upstream and are covered by the upstream test suite.

## Build & Deploy

```bash
# Local build (run from buildfiles/ or repo root)
./buildfiles/build-locally.sh

```

The GitHub workflow publishes images to the configured prokube Artifact Registry
on pushes to `pk-internal-build-branch` and on version tags. Pull requests build
the image without registry credentials and do not publish it.
