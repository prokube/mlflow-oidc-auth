ARG BASE_IMAGE=python:3.14-slim

FROM node:24-bookworm-slim AS frontend
WORKDIR /build/web-react
COPY web-react/package.json web-react/yarn.lock ./
RUN yarn install --frozen-lockfile
COPY web-react/ ./
RUN yarn build

FROM ${BASE_IMAGE} AS builder
ARG MLFLOW_OIDC_AUTH_VERSION
ARG MLFLOW_VERSION
ENV MLFLOW_OIDC_AUTH_VERSION=${MLFLOW_OIDC_AUTH_VERSION}
COPY --from=ghcr.io/astral-sh/uv:0.9.26 /uv /bin/uv
WORKDIR /build
COPY pyproject.toml README.md LICENSE ./
COPY mlflow_oidc_auth/ mlflow_oidc_auth/
COPY --from=frontend /build/mlflow_oidc_auth/ui/ mlflow_oidc_auth/ui/
RUN uv build --wheel --out-dir /dist
RUN uv venv /mlflow/.venv && \
    uv pip install --python /mlflow/.venv/bin/python --no-cache \
        "mlflow==${MLFLOW_VERSION}" /dist/mlflow_oidc_auth-*.whl \
        "boto3>=1.42.26" "azure-storage-blob>=12.25.1" \
        "azure-identity>=1.25.1" "google-cloud-storage>=3.1.0" \
        "psycopg[binary]>=3.2,<4" "psycopg2-binary==2.9.11" && \
    uv pip check --python /mlflow/.venv/bin/python

FROM ${BASE_IMAGE} AS final
ARG MLFLOW_OIDC_AUTH_VERSION
ARG MLFLOW_VERSION
LABEL org.opencontainers.image.title="prokube MLflow OIDC Auth" \
      org.opencontainers.image.version="mlflow-${MLFLOW_VERSION}_oidc-${MLFLOW_OIDC_AUTH_VERSION}"
RUN apt-get update && apt-get install -y --no-install-recommends tini && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    adduser --disabled-password --gecos '' python && \
    install -d -o python -g python /mlflow
WORKDIR /mlflow
COPY --chown=python:python --from=builder /mlflow/.venv /mlflow/.venv
ENV PATH=/mlflow/.venv/bin:$PATH \
    MLFLOW_OIDC_AUTH_VERSION=${MLFLOW_OIDC_AUTH_VERSION}
USER python
EXPOSE 5000
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["mlflow", "server", "--host", "0.0.0.0", "--port", "5000", "--app-name", "oidc-auth", "--backend-store-uri", "sqlite:///mlflow.db", "--default-artifact-root", "/mlflow/artifacts"]
