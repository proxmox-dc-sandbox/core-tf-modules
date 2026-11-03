# pdcs-core-tf-modules — developer makefile
#
# Targets:
#   make fmt           tofu fmt -check on modules + examples
#   make validate      tofu init -backend=false && validate on every module
#   make hcl           terragrunt hcl fmt/validate on the reference client
#   make lint          shellcheck on the wrapper scripts
#   make security      gitleaks over the full history (default rules)
#   make check         fmt + validate + hcl (same checks as the CI)
#   make image         build the tools image (docker/Dockerfile)

SOURCES := 01-foundation 02-networking 03-compute
MODULES  := $(wildcard modules/*)
EXAMPLES := 01-foundation/examples/test-local 02-networking/examples/test-local 03-compute/examples/test-local

.PHONY: fmt validate hcl lint security check image

fmt:
	tofu fmt -check -recursive $(SOURCES) modules examples

validate:
	@status=0; \
	for d in $(SOURCES) $(MODULES) $(EXAMPLES); do \
		[ -f "$$d/main.tf" ] || continue; \
		echo "   validate $$d"; \
		(cd "$$d" && tofu init -backend=false -input=false >/dev/null \
			&& tofu validate) || status=1; \
	done; \
	exit $$status

hcl:
	terragrunt hcl fmt --check .
	terragrunt hcl fmt --check examples/terragrunt-client
	cd examples/terragrunt-client && terragrunt hcl validate

lint:
	@status=0; \
	while IFS= read -r -d '' f; do \
		shellcheck -x "$$f" || status=1; \
	done < <(find . -name "*.sh" -type f -not -path "./.git/*" -print0); \
	exit $$status

security:
	gitleaks detect --source . --verbose --redact --no-banner

check: fmt validate hcl

image:
	docker build -f docker/Dockerfile -t pdcs-core-tf-modules:dev .
