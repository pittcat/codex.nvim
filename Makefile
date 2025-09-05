.PHONY: test

test:
	@nvim --headless -u tests/minimal_init.lua +"lua dofile('tests/run_basic.lua')"
	@nvim --headless -u tests/minimal_init.lua +"lua dofile('tests/run_commands.lua')"
	@echo "All tests passed"

