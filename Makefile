.DEFAULT_GOAL := check
.PHONY: help check check-repository check-bootstrap check-profiles check-platforms \
	check-profile-state check-vscode check-templates lint-template \
	check-assistant-configs

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

CHEZMOI ?= chezmoi
CHEZMOI_SOURCE ?= $(ROOT_DIR)
TEMPLATE_PATH ?=
FIX ?=
CHECK_TRACE ?=

export CHEZMOI CHEZMOI_SOURCE TEMPLATE_PATH CHECK_TRACE

ASSISTANT_CONFIGS := \
	.agents/hooks.json \
	.claude/settings.json \
	.codex/hooks.json \
	.gemini/settings.json \
	.github/hooks/hooks.json

FIX_FLAG := $(if $(filter 1 true yes,$(FIX)),--fix,)

help:
	@printf '%s\n' \
	  'Available targets:' \
	  '  make check                       Run all repository checks' \
	  '  make check-repository            Run isolated configuration and behavior tests' \
	  '  make check-bootstrap             Check starter-data and installer bootstrap' \
	  '  make check-profiles              Check profile templates and shell integration' \
	  '  make check-platforms             Check platform-specific templates and packages' \
	  '  make check-profile-state         Check profile setup behavior' \
	  '  make check-vscode                Check VS Code profile and settings behavior' \
	  '  make check-templates             Check whitespace in Go templates' \
	  '  make lint-template               Check all Go templates' \
	  '  make lint-template TEMPLATE_PATH=path [FIX=1]' \
	  '                                   Check one file or directory; FIX=1 normalizes whitespace' \
	  '  make check-assistant-configs     Validate assistant hook and tool JSON'

check: check-repository check-templates check-assistant-configs

check-repository:
	@$(SHELL) "$(ROOT_DIR)/scripts/check.sh"

check-bootstrap:
	@$(SHELL) "$(ROOT_DIR)/scripts/check.sh" bootstrap

check-profiles:
	@$(SHELL) "$(ROOT_DIR)/scripts/check.sh" profiles

check-platforms:
	@$(SHELL) "$(ROOT_DIR)/scripts/check.sh" platforms

check-profile-state:
	@$(SHELL) "$(ROOT_DIR)/scripts/check.sh" profile-state

check-vscode:
	@$(SHELL) "$(ROOT_DIR)/scripts/check.sh" vscode

check-templates:
	@TEMPLATE_PATH= $(SHELL) "$(ROOT_DIR)/scripts/lint-template.sh"

lint-template:
	@$(SHELL) "$(ROOT_DIR)/scripts/lint-template.sh" $(FIX_FLAG)

check-assistant-configs:
	@set -eu; \
	for file in $(ASSISTANT_CONFIGS); do \
	  python3 -m json.tool "$(ROOT_DIR)/$$file" > /dev/null; \
	done; \
	printf '%s\n' 'Assistant config JSON is valid.'
