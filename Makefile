# =============================================================================
# curso-kolbit — automatización local
#   make help        lista de objetivos
#   make ci          lo mismo que haría el CI: lint + build + imagen + smoke test
# Motor de contenedores: podman por defecto (ENGINE=docker para usar Docker)
# =============================================================================

SHELL        := bash
.SHELLFLAGS  := -eu -o pipefail -c
.DEFAULT_GOAL := help
MAKEFLAGS    += --no-print-directory

ENGINE       ?= podman
REGISTRY     ?= ghcr.io
GH_USER      ?= ibannieto
IMAGE        ?= $(REGISTRY)/$(GH_USER)/curso-kolbit
PLATFORM     ?= linux/amd64
GIT_SHA      := $(shell git rev-parse --short HEAD 2>/dev/null || echo nogit)
DIRTY        := $(shell git diff --quiet HEAD 2>/dev/null || echo -dirty)
TAG          ?= $(GIT_SHA)$(DIRTY)
CREATED      := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

NETWORK      ?= kolbit
CONTAINER    ?= curso-kolbit
PORT         ?= 8080
URL          ?= http://localhost:$(PORT)

K8S_NS       ?= curso-kolbit
OVERLAY      ?= k8s/overlays/hetzner
KUBECTL      ?= kubectl

DECKTAPE_IMAGE ?= ghcr.io/astefanutti/decktape:3.17.0
PDF          ?= output/curso-kolbit.pdf

# Linters: binario local si existe; si no, contenedor con versión fijada
HADOLINT     := $(or $(shell command -v hadolint),$(ENGINE) run --rm -v $(CURDIR):/w:z -w /w ghcr.io/hadolint/hadolint:v2.15.1 hadolint)
SHELLCHECK   := $(or $(shell command -v shellcheck),$(ENGINE) run --rm -v $(CURDIR):/mnt:z -w /mnt docker.io/koalaman/shellcheck-alpine:v0.11.0 shellcheck)
ACTIONLINT   := $(or $(shell command -v actionlint),$(ENGINE) run --rm -v $(CURDIR):/repo:z -w /repo docker.io/rhysd/actionlint:1.7.12)
KUBECONFORM  := $(or $(shell command -v kubeconform),$(ENGINE) run --rm -i ghcr.io/yannh/kubeconform:v0.8.0)
YAMLLINT     := $(or $(shell command -v yamllint),$(ENGINE) run --rm -v $(CURDIR):/data:z -w /data docker.io/pipelinecomponents/yamllint:0.35.27 yamllint)

##@ Presentación

node_modules: package.json package-lock.json
	npm ci --no-audit --no-fund
	@touch node_modules

.PHONY: install
install: node_modules ## Instala dependencias npm

.PHONY: dev
dev: node_modules ## Servidor local con recarga en http://localhost:8000
	npm run dev

.PHONY: build
build: node_modules ## Genera la web estática en dist/
	npm run build

.PHONY: stats
stats: ## Diapositivas por módulo y estimación de duración
	@node scripts/stats.mjs

.PHONY: assets
assets: ## Vuelve a descargar las imágenes oficiales (assets/img)
	./scripts/fetch-assets.sh

##@ Calidad

.PHONY: lint
lint: lint-md lint-yaml lint-docker lint-k8s lint-sh lint-actions ## Ejecuta todos los linters

.PHONY: lint-md
lint-md: node_modules ## Markdown (slides, labs, docs)
	npx --no-install markdownlint-cli2

.PHONY: lint-yaml
lint-yaml: ## YAML (manifiestos, compose, workflows)
	$(YAMLLINT) -c .yamllint.yaml -s k8s examples .github

.PHONY: lint-docker
lint-docker: ## Dockerfiles con hadolint
	$(HADOLINT) -c .hadolint.yaml Dockerfile examples/contador/Dockerfile

.PHONY: lint-k8s
lint-k8s: ## Valida manifiestos con kubeconform (Kubernetes 1.37)
	@for d in k8s/overlays/* examples/contador/k8s; do \
	  echo "kubeconform $$d"; \
	  $(KUBECTL) kustomize $$d | $(KUBECONFORM) -strict -summary -kubernetes-version 1.37.0 -ignore-missing-schemas -; \
	done
	@if [ -d examples/contador/k8s/admin ]; then \
	  find examples/contador/k8s/admin -name '*.yaml' -print0 | xargs -0 $(KUBECONFORM) -strict -summary -kubernetes-version 1.37.0 -ignore-missing-schemas; \
	fi

.PHONY: lint-sh
lint-sh: ## Scripts de shell con shellcheck
	$(SHELLCHECK) scripts/*.sh

.PHONY: lint-actions
lint-actions: ## Workflows de GitHub Actions con actionlint
	$(ACTIONLINT)

.PHONY: secrets-scan
secrets-scan: ## Busca secretos con gitleaks (si está instalado)
	@command -v gitleaks >/dev/null && gitleaks git --no-banner --redact . || echo "gitleaks no instalado, omitido"

##@ Contenedor

.PHONY: image
image: ## Construye la imagen (IMAGE:TAG, TAG = commit corto)
	$(ENGINE) build $(if $(filter podman,$(ENGINE)),--format docker) \
	  --platform $(PLATFORM) \
	  --build-arg VERSION=$(TAG) --build-arg GIT_SHA=$(GIT_SHA) --build-arg CREATED=$(CREATED) \
	  -t $(IMAGE):$(TAG) -t $(IMAGE):latest -t localhost/curso-kolbit:dev .

.PHONY: run
run: ## Arranca la presentación en http://localhost:8080
	@$(ENGINE) network inspect $(NETWORK) >/dev/null 2>&1 || $(ENGINE) network create $(NETWORK) >/dev/null
	@$(ENGINE) rm -f $(CONTAINER) >/dev/null 2>&1 || true
	$(ENGINE) run -d --name $(CONTAINER) --network $(NETWORK) -p $(PORT):8080 --read-only --tmpfs /tmp \
	  --cap-drop ALL --security-opt no-new-privileges $(IMAGE):$(TAG)
	@./scripts/wait-for.sh $(URL)/healthz
	@echo "▶ $(URL)"

.PHONY: stop
stop: ## Para y elimina el contenedor local
	-$(ENGINE) rm -f $(CONTAINER)

.PHONY: smoke
smoke: ## Smoke test contra el contenedor en marcha
	./scripts/smoke-test.sh $(URL)

.PHONY: pdf
pdf: ## Exporta la presentación a PDF (output/curso-kolbit.pdf)
	@$(ENGINE) container inspect $(CONTAINER) >/dev/null 2>&1 || $(MAKE) run
	ENGINE=$(ENGINE) NETWORK=$(NETWORK) CONTAINER=$(CONTAINER) DECKTAPE_IMAGE=$(DECKTAPE_IMAGE) ./scripts/pdf.sh $(PDF)

.PHONY: shots
shots: ## Capturas PNG de cada diapositiva en output/shots (revisión visual)
	@$(ENGINE) container inspect $(CONTAINER) >/dev/null 2>&1 || $(MAKE) run
	ENGINE=$(ENGINE) CONTAINER_NAME=$(CONTAINER) DECKTAPE_IMAGE=$(DECKTAPE_IMAGE) ./scripts/render-check.sh "$(SLIDES)" output/shots

.PHONY: login
login: ## Login en GHCR con el token de gh (requiere scope write:packages)
	@gh auth status 2>&1 | grep -q 'write:packages' || { echo "✖ El token de gh no tiene write:packages. Ejecuta: gh auth refresh -h github.com -s write:packages"; exit 1; }
	gh auth token | $(ENGINE) login $(REGISTRY) -u $(GH_USER) --password-stdin

.PHONY: push
push: ## Sube IMAGE:TAG y :latest a GHCR (desde este equipo, no desde CI)
	@if [ -n "$(DIRTY)" ] && [ -z "$(FORCE)" ]; then echo "✖ Hay cambios sin commitear (TAG=$(TAG)). Haz commit o usa FORCE=1"; exit 1; fi
	$(ENGINE) push $(IMAGE):$(TAG)
	$(ENGINE) push $(IMAGE):latest
	@echo "✔ Publicada $(IMAGE):$(TAG)"

.PHONY: release
release: ci push ## ci + push

##@ Kubernetes

.PHONY: deploy
deploy: ## Despliega IMAGE:TAG en el contexto actual (overlay hetzner)
	@if [ -n "$(DIRTY)" ] && [ -z "$(FORCE)" ]; then echo "✖ Hay cambios sin commitear: el tag $(TAG) no existe en el registro. Haz commit + make image push, o usa FORCE=1"; exit 1; fi
	@echo "Contexto: $$($(KUBECTL) config current-context)"
	sed -i -E 's|^(    newTag: ).*(# managed-by: make deploy)$$|\1$(TAG) \2|' $(OVERLAY)/kustomization.yaml
	$(KUBECTL) apply -k $(OVERLAY)
	$(KUBECTL) -n $(K8S_NS) rollout status deploy/curso-kolbit --timeout=180s
	@echo "✔ Desplegado $(TAG). Recuerda commitear $(OVERLAY)/kustomization.yaml"

.PHONY: k8s-status
k8s-status: ## Estado de la presentación en el clúster
	$(KUBECTL) -n $(K8S_NS) get deploy,rs,pods,svc,pdb,netpol -o wide
	@$(KUBECTL) -n $(K8S_NS) get deploy curso-kolbit -o jsonpath='{"Imagen: "}{.spec.template.spec.containers[0].image}{"\n"}'

.PHONY: k8s-forward
k8s-forward: ## Port-forward del Service a http://localhost:8081
	$(KUBECTL) -n $(K8S_NS) port-forward svc/curso-kolbit 8081:80

.PHONY: k8s-smoke
k8s-smoke: ## Smoke test en el clúster (port-forward temporal)
	@$(KUBECTL) -n $(K8S_NS) port-forward svc/curso-kolbit 8081:80 >/dev/null 2>&1 & pf=$$!; \
	  trap "kill $$pf" EXIT; ./scripts/wait-for.sh http://localhost:8081/healthz && ./scripts/smoke-test.sh http://localhost:8081

.PHONY: k8s-delete
k8s-delete: ## Elimina la presentación del clúster
	$(KUBECTL) delete -k $(OVERLAY) --ignore-not-found

##@ Integración

.PHONY: ci
ci: lint build image run smoke ## Pipeline local completo (equivalente al CI de GitHub)
	@$(MAKE) stop >/dev/null
	@echo "✔ CI local OK ($(IMAGE):$(TAG))"

.PHONY: hooks
hooks: ## Instala el hook pre-commit (lint rápido)
	git config core.hooksPath .githooks
	@echo "✔ Hooks activados (.githooks/pre-commit)"

.PHONY: clean
clean: ## Borra artefactos generados
	rm -rf dist output

.PHONY: help
help: ## Muestra esta ayuda
	@awk 'BEGIN {FS = ":.*##"; printf "\nUso: make \033[36m<objetivo>\033[0m  (ENGINE=$(ENGINE) IMAGE=$(IMAGE) TAG=$(TAG))\n"} \
	  /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 } \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
