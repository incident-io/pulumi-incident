# PLACEHOLDER. ci-mgmt owns this file for real bridged providers — running
# `provider-ci generate` (see .ci-mgmt.yaml) replaces it with a ~300 line
# version carrying crossbuild, .make/ staleness stamps, per-language SDK builds
# and the targets the release workflows call. This exists only so the repo is
# buildable before that first generation. Put local additions in .mk/*.mk,
# which the generated Makefile includes.

PACK            := incident
ORG             := incident-io
PROJECT         := github.com/$(ORG)/pulumi-$(PACK)
PROVIDER_PATH   := provider
VERSION_PATH    := $(PROVIDER_PATH)/pkg/version.Version

TFGEN           := pulumi-tfgen-$(PACK)
PROVIDER        := pulumi-resource-$(PACK)
SCHEMA_PATH     := provider/cmd/$(PROVIDER)

WORKING_DIR     := $(shell pwd)

# A leading "v" is invalid as an npm/PyPI/NuGet version, so strip it.
VERSION         ?= $(patsubst v%,%,$(shell git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0-alpha.0+dev"))

LDFLAGS         := -X $(PROJECT)/$(VERSION_PATH)=$(VERSION)

# Converting the upstream HCL examples into per-language Pulumi examples needs
# the pulumi CLI on PATH. Without it tfgen panics rather than degrading, so the
# schema would be generated with no examples at all.
export PULUMI_CONVERT := 1

# Where the upstream Terraform provider is checked out. Required while
# provider/go.mod carries a filesystem replace: the bridge otherwise infers the
# docs location from Go's module cache, and that inference fails silently on a
# replace, emptying every example out of the schema.
UPSTREAM_REPO_PATH ?=
export UPSTREAM_REPO_PATH

# Turn missing docs into a build failure rather than 42 warnings nobody reads.
export PULUMI_MISSING_DOCS_ERROR := true

GO_SOURCES := $(shell find provider -name '*.go' -not -name '*_test.go')

.PHONY: development tfgen provider build_sdks build_% clean help

development: tfgen provider build_sdks ## Full local build.

# Stamps rather than the binaries themselves: `go build -o` rewrites its output
# unconditionally, so depending on the binary would re-run schema generation on
# every invocation. The stamp only moves when a source file actually changes.
.make/$(TFGEN): $(GO_SOURCES)
	@mkdir -p .make bin
	(cd provider && go build -o $(WORKING_DIR)/bin/$(TFGEN) -ldflags "$(LDFLAGS)" $(PROJECT)/$(PROVIDER_PATH)/cmd/$(TFGEN))
	@touch $@

# Stamped as well, because tfgen skips the write when the schema is unchanged,
# leaving schema.json older than the binary that produced it.
.make/schema: .make/$(TFGEN)
	@test -n "$(UPSTREAM_REPO_PATH)" || \
		{ echo "UPSTREAM_REPO_PATH is unset — see README"; exit 1; }
	$(WORKING_DIR)/bin/$(TFGEN) schema --out $(SCHEMA_PATH)
	@touch $@

tfgen: .make/schema ## Generate the Pulumi Package Schema from the bridged provider.

# Depends on the schema because main.go embeds it — without this, `make -j`
# can link the plugin around a stale schema.
provider: .make/schema ## Build the provider plugin binary.
	(cd provider && go build -o $(WORKING_DIR)/bin/$(PROVIDER) -ldflags "$(LDFLAGS)" $(PROJECT)/$(PROVIDER_PATH)/cmd/$(PROVIDER))

build_sdks: build_nodejs build_python build_go build_dotnet ## Generate every language SDK.

# Safe under `make -j`: disjoint output dirs over one read-only input. Language
# targets read the generated schema rather than re-running conversion.
build_%: .make/schema
	$(WORKING_DIR)/bin/$(TFGEN) $* --out sdk/$*/

clean: ## Remove build output. Leaves committed SDK sources alone.
	rm -rf bin .make sdk/nodejs sdk/python sdk/go sdk/dotnet

help:
	@grep -E '^[a-zA-Z_%-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'
