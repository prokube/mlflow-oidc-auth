ARG BASE_IMAGE=python:3.13-slim
FROM ${BASE_IMAGE} AS builder
COPY /dist /dist
WORKDIR /dist

RUN python3 -m venv .venv
ENV PATH="/dist/.venv/bin:$PATH"
RUN --mount=from=ghcr.io/astral-sh/uv,source=/uv,target=/bin/uv \
    uv pip install --no-cache-dir mlflow-*.tar.gz mlflow_oidc_auth-*.tar.gz \
    uv pip install --no-cache-dir "boto3>=1.37.34" "azure-storage-blob>=12.25.1" "azure-identity>=1.21.0" "google-cloud-storage>=3.1.0" "psycopg2-binary==2.9.10"

FROM ${BASE_IMAGE} AS final

RUN adduser --disabled-password --gecos '' python
USER python

WORKDIR /mlflow
COPY --chown=python:python --from=builder /dist/.venv /mlflow/.venv

ENV PATH=/mlflow/.venv/bin:$PATH
ENV OAUTHLIB_INSECURE_TRANSPORT=1
EXPOSE 5000
CMD ["mlflow", "server", "--host", "0.0.0.0", "--port", "5000", "--app-name", "oidc-auth", "--backend-store-uri", "sqlite:///mlflow.db", "--default-artifact-root", "/mlflow/artifacts"]
