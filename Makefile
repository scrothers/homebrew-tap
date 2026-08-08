# scrothers/tap — local interface to the tap.
#
# Homebrew strips the `homebrew-` prefix, so this repo has two names:
#   tap name   scrothers/tap          brew style / audit / livecheck / bump / install
#   repo name  scrothers/homebrew-tap brew pr-pull, $GITHUB_REPOSITORY
# They are not interchangeable. See CLAUDE.md.

SHELL       := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

BREW    ?= $(shell command -v brew 2>/dev/null || echo /home/linuxbrew/.linuxbrew/bin/brew)
TAP     := scrothers/tap
ROOT    := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
TAPS    := $(shell $(BREW) --repository 2>/dev/null)/Library/Taps
TAP_DIR := $(TAPS)/scrothers/homebrew-tap
ZIZMOR  := 1.29.0

# Formula files present right now. Several targets no-op cleanly when this is empty,
# which is the normal state of a tap that has not had its first formula yet.
FORMULAE := $(wildcard Formula/*.rb)

.PHONY: help tap untap style fix syntax audit test livecheck bump-dry \
        readme readme-check new-formula lint all clean

help: ## Show this help
	@echo "scrothers/tap — make targets"
	@echo
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) \
	  | sort \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Formulae: $(if $(FORMULAE),$(words $(FORMULAE)),none yet)"

## --- wiring ----------------------------------------------------------------

tap: ## Symlink this checkout into Homebrew's Taps dir (run once per checkout)
	@if [ -L "$(TAP_DIR)" ]; then \
	  echo "already linked: $(TAP_DIR) -> $$(readlink "$(TAP_DIR)")"; \
	elif [ -e "$(TAP_DIR)" ]; then \
	  echo "ERROR: $(TAP_DIR) exists and is not a symlink." >&2; \
	  echo "       Refusing to touch it. Inspect and remove it yourself." >&2; \
	  exit 1; \
	else \
	  mkdir -p "$$(dirname "$(TAP_DIR)")"; \
	  ln -s "$(ROOT)" "$(TAP_DIR)"; \
	  echo "linked $(TAP_DIR) -> $(ROOT)"; \
	fi

untap: ## Remove the symlink created by `make tap` (never removes a real directory)
	@if [ -L "$(TAP_DIR)" ]; then \
	  rm "$(TAP_DIR)"; echo "unlinked $(TAP_DIR)"; \
	elif [ -e "$(TAP_DIR)" ]; then \
	  echo "ERROR: $(TAP_DIR) is not a symlink. Refusing to remove it." >&2; exit 1; \
	else \
	  echo "not linked; nothing to do"; \
	fi

## --- formula checks --------------------------------------------------------

style: ## Run brew style (Homebrew's RuboCop ruleset) over the tap
	$(BREW) style $(TAP)

fix: ## Run brew style --fix
	$(BREW) style --fix $(TAP)

syntax: ## Run the same syntax check CI runs
	$(BREW) test-bot --only-tap-syntax --tap=$(TAP)

audit: ## Run brew audit --strict --online over the tap
	@if [ -z "$(FORMULAE)" ]; then echo "no formulae yet; skipping audit"; exit 0; fi
	$(BREW) audit --strict --online --tap=$(TAP)

test: ## Run a formula's test block: make test F=<name>
	@if [ -z "$(F)" ]; then echo "usage: make test F=<formula>" >&2; exit 2; fi
	$(BREW) test $(TAP)/$(F)

livecheck: ## Check every formula against its upstream for a newer version
	@if [ -z "$(FORMULAE)" ]; then echo "no formulae yet; skipping livecheck"; exit 0; fi
	$(BREW) livecheck --tap=$(TAP)

bump-dry: ## Show what autobump would do, without opening any PR
	@if [ -z "$(FORMULAE)" ]; then echo "no formulae yet; skipping bump"; exit 0; fi
	$(BREW) bump --formulae --tap=$(TAP)

## --- generation ------------------------------------------------------------

new-formula: ## Scaffold a formula: make new-formula NAME=foo REPO=owner/repo
	@if [ -z "$(NAME)" ] || [ -z "$(REPO)" ]; then \
	  echo "usage: make new-formula NAME=<formula> REPO=<owner/repo>" >&2; exit 2; fi
	ruby scripts/new-formula.rb --name "$(NAME)" --repo "$(REPO)"

readme: ## Regenerate the formula table in README.md
	ruby scripts/gen-readme.rb

readme-check: ## Fail if the README formula table is out of date
	ruby scripts/gen-readme.rb --check

## --- workflows -------------------------------------------------------------

lint: ## Security-audit the GitHub Actions workflows (zizmor)
	@# actionlint and shellcheck are not run here: `brew style` already runs both over
	@# .github/workflows, so `make style` and `make syntax` cover them. zizmor is the
	@# part Homebrew does not do.
	@if command -v zizmor >/dev/null 2>&1; then \
	  zizmor .github/workflows/; \
	elif command -v uvx >/dev/null 2>&1; then \
	  uvx zizmor@$(ZIZMOR) .github/workflows/; \
	else \
	  echo "zizmor not installed and uvx unavailable; skipping (CI still runs it)"; \
	fi

## --- aggregate -------------------------------------------------------------

all: style syntax audit readme-check lint ## Everything CI checks, locally
	@echo
	@echo "all checks passed"

clean: ## Remove bottle artefacts and test-bot output left in the tap root
	rm -f ./*.bottle.* ./*.bottle.json ./steps_output.txt ./brew-test-bot.log
