all: help

test: ## Run the full test suite (R package, shell installer, opencode plugin)
	Rscript -e 'testthat::test_local("bindings/r")'
	bash tests/test-install-hooks.sh
	bun test agent-hooks/opencode/askfirst-plugin.test.js

help: ## Show this help
	@printf "Usage:\033[36m make [target]\033[0m\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
