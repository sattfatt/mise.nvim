.PHONY: test test-file test-watch lint

PLENARY_PATH ?= $(HOME)/.local/share/nvim/lazy/plenary.nvim

# Run all tests
test:
	nvim --headless \
		-u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/specs/ {sequential = true}" \
		2>&1

# Run a single test file: make test-file FILE=tests/specs/config_spec.lua
test-file:
	nvim --headless \
		-u tests/minimal_init.lua \
		-c "PlenaryBustedFile $(FILE)" \
		2>&1

# Run tests and exit with proper code (useful for CI)
test-ci:
	@nvim --headless \
		-u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/specs/ {sequential = true}" \
		2>&1; \
	EXIT=$$?; \
	exit $$EXIT
