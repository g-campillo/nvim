# Fresh-Mac bootstrap for this Neovim config.
#
#   make install   install every external dependency (idempotent, safe to re-run)
#   make doctor    check what's installed and what nvim will see
#
# Neovim plugins and LSP servers install themselves on first `nvim` launch
# (lazy.nvim + Mason); this only handles the system-level deps they need.
# Logic lives in scripts/setup.sh — macOS ships GNU make 3.81, which is bad at
# multi-line shell recipes, so each target is a one-line delegation.

.DEFAULT_GOAL := help
.PHONY: install doctor help

help:
	@echo "make install   install all deps: neovim, brew, FiraCode Nerd Font, ripgrep,"
	@echo "               node (nvm), python (pyenv), java (sdkman: JDK 21 + 17)"
	@echo "make doctor    verify what's installed"

install:
	@bash scripts/setup.sh install

doctor:
	@bash scripts/setup.sh doctor
