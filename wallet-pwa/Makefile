.PHONY: all test

ifeq (version,$(firstword $(MAKECMDGOALS)))
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(RUN_ARGS):;@:)
endif

install: ## Install project dependencies
	@yarn install

lint: ## Run project lint.
	@yarn lint

test: ## Run project tests.
	@yarn test
