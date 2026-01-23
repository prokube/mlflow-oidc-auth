ARG PYTHON_VERSION=3.12-slim
FROM python:${PYTHON_VERSION} AS base

LABEL org.opencontainers.image.authors="Alexander Kharkevich <alex@kharkevich.org>"
LABEL org.opencontainers.image.source="https://github.com/mlflow-oidc/mlflow-oidc-auth"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.description="MLFlow tracking server with OpenID Connect authentication"

RUN adduser --disabled-password --gecos '' python
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

FROM base AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libffi-dev \
    libssl-dev \
    zlib1g-dev \
    make \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js for building the UI
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn

# Install uv for fast Python package management
RUN pip install --no-cache-dir uv

WORKDIR /build

# Copy web-react and build it first
COPY web-react/ /build/web-react/
RUN cd /build/web-react && \
    yarn install --frozen-lockfile && \
    yarn build

# Create mlflow directory structure
RUN mkdir -p /mlflow && chown python:python /mlflow

USER python
WORKDIR /mlflow

# Copy the mlflow-oidc-auth package
COPY --chown=python:python mlflow_oidc_auth/ /mlflow/mlflow_oidc_auth/
COPY --chown=python:python mlflow_oidc_auth_pyproject.toml /mlflow/pyproject.toml

# Copy the built UI (vite outputs to ../mlflow_oidc_auth/ui relative to web-react)
RUN mkdir -p /mlflow/mlflow_oidc_auth/ui && \
    cp -r /build/mlflow_oidc_auth/ui/* /mlflow/mlflow_oidc_auth/ui/

# Create virtual environment and install dependencies
RUN uv venv /mlflow/.venv && \
    . /mlflow/.venv/bin/activate && \
    uv pip install -e .[cloud]

# Install additional dependencies for the docker image
COPY --chown=python:python pyproject.toml /mlflow/docker-deps.toml
RUN . /mlflow/.venv/bin/activate && \
    uv pip install \
    "mlflow>=3.8.1,<4" \
    "boto3>=1.42.26" \
    "azure-storage-blob>=12.25.1" \
    "azure-identity>=1.25.1" \
    "google-cloud-storage>=3.1.0" \
    "psycopg2-binary>=2.9.10"

FROM base AS final
USER root
COPY buildfiles/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
USER python
WORKDIR /mlflow
COPY --from=builder --chown=python:python /mlflow /mlflow
ENV PATH=/mlflow/.venv/bin:$PATH
ENV OAUTHLIB_INSECURE_TRANSPORT=1
EXPOSE 5000
ENTRYPOINT ["/entrypoint.sh"]
CMD ["mlflow", "server", "--host", "0.0.0.0", "--port", "5000", "--app-name", "oidc-auth", "--backend-store-uri", "sqlite:///mlflow.db", "--default-artifact-root", "/mlflow/artifacts"]
