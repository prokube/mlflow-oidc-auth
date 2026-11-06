MLFLOW_VERSION ?= 3.17.2
MLFLOW_OIDC_AUTH_VERSION ?= 11.0.2
IMAGE ?= mlflow-oidc-auth:mlflow-$(MLFLOW_VERSION)-oidc-$(MLFLOW_OIDC_AUTH_VERSION)
PLATFORM ?= linux/amd64

.PHONY: build-image smoke-image print-oidc-version

print-oidc-version:
	@printf '%s\n' '$(MLFLOW_OIDC_AUTH_VERSION)'

build-image:
	docker build --platform $(PLATFORM) \
		--build-arg MLFLOW_VERSION=$(MLFLOW_VERSION) \
		--build-arg MLFLOW_OIDC_AUTH_VERSION=$(MLFLOW_OIDC_AUTH_VERSION) \
		-t $(IMAGE) .

smoke-image:
	docker run --rm --platform $(PLATFORM) $(IMAGE) python -c \
		'from importlib.metadata import version; assert version("mlflow") == "$(MLFLOW_VERSION)"; assert version("mlflow-oidc-auth") == "$(MLFLOW_OIDC_AUTH_VERSION)"; print("MLflow", version("mlflow"), "OIDC", version("mlflow-oidc-auth"))'
