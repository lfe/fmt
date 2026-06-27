.PHONY: all compile clean test eunit ct proper xref dialyzer \
        format format-check \
        oracle oracle-fmt oracle-clippy oracle-build oracle-test diff-oracle \
        check ci console help

REBAR := rebar3
CARGO := cargo
APP_NAME := lfmt
APP_VERSION := $(shell grep vsn src/$(APP_NAME).app.src | cut -d'"' -f2)
ORACLE_DIR := test/oracle

all: compile

compile:
	@$(REBAR) compile

clean:
	@$(REBAR) clean
	@rm -rf _build logs erl_crash.dump

## === Erlang checks (mirror CI: core-builds + dialyzer jobs) ===

xref:
	@$(REBAR) xref

dialyzer:
	@$(REBAR) dialyzer

eunit:
	@$(REBAR) as test eunit

ct:
	@$(REBAR) ct

proper:
	@$(REBAR) as test do compile, proper --regressions

# All Erlang tests, in CI order (compile happens first).
test: compile proper ct eunit
	@echo "Erlang tests passed."

## === Erlang formatting (NOT a CI gate — see note in `check`) ===

format:
	@$(REBAR) fmt

format-check:
	@$(REBAR) fmt --check

## === Rust oracle (mirror CI: oracle-rust job; runs in $(ORACLE_DIR)) ===

oracle-fmt:
	@cd $(ORACLE_DIR) && $(CARGO) fmt --check

oracle-clippy:
	@cd $(ORACLE_DIR) && $(CARGO) clippy --all-targets --locked -- -D warnings

oracle-build:
	@cd $(ORACLE_DIR) && $(CARGO) build --release --locked

oracle-test:
	@cd $(ORACLE_DIR) && $(CARGO) test --locked

oracle: oracle-fmt oracle-clippy oracle-build oracle-test
	@echo "Rust oracle checks passed."

## === Differential oracle (mirror CI: differential-oracle job) ===

# Builds the mjl reference binary, compiles the test profile, then renders
# random docs through both engines asserting reported-cost equality.
diff-oracle: oracle-build
	@$(REBAR) as test compile
	@escript bench/pe_oracle 200

## === Aggregate gates ===

# Erlang inner loop: compile + static analysis + all Erlang tests.
check: compile xref dialyzer test
	@echo "Erlang checks passed."

# Full CI-equivalent gate: every check CI runs across all four jobs. Run this
# before pushing for zero surprises.
#
# NOTE: `format-check` (erlfmt) is deliberately NOT part of check/ci, because CI
# does not gate erlfmt on the Erlang source (the only format gate is the Rust
# oracle's `cargo fmt`, covered by `oracle-fmt`). Keeping `make ci` == CI avoids
# false local failures on the not-yet-erlfmt-clean source. Run `make format-check`
# manually if you want to see erlfmt drift.
#
# NOTE: CI runs the Erlang jobs across OTP 27/28/29; `make ci` runs against your
# locally-installed OTP only. The multi-OTP matrix remains CI's job.
ci: check oracle diff-oracle
	@echo "Full CI-equivalent gate passed."

console:
	@$(REBAR) shell

help:
	@echo "$(APP_NAME) v$(APP_VERSION) - Available targets:"
	@echo "  make compile       - Compile the project"
	@echo "  make clean         - Clean build artifacts"
	@echo "  make test          - Run all Erlang tests (proper, ct, eunit)"
	@echo "  make xref          - Run xref analysis"
	@echo "  make dialyzer      - Run Dialyzer"
	@echo "  make format        - Format Erlang source (erlfmt, in place)"
	@echo "  make format-check  - Check erlfmt formatting (not a CI gate)"
	@echo "  make oracle        - Run the Rust oracle checks (fmt, clippy, build, test)"
	@echo "  make diff-oracle   - Run the mjl differential oracle"
	@echo "  make check         - Erlang gate: compile, xref, dialyzer, tests"
	@echo "  make ci            - FULL CI-equivalent gate (check + oracle + diff-oracle)"
	@echo "  make console       - Start a rebar3 shell"
	@echo "  make help          - Show this help message"
