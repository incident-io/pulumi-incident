# Local additions. The generated Makefile ends with `include $(wildcard .mk/*.mk)`,
# so this file survives `make ci-mgmt`.

# Two fixes to the generated resync-build.yml, which regenerates the workflows
# monthly and opens a PR with the result.
#
# 1. ci-mgmt hardcodes `base: main` and never substitutes providerDefaultBranch
#    (which defaults to master, and is why master.yml is named that). Our
#    default branch is master, so the PR targets a branch that does not exist.
#
# 2. The job runs `make ci-mgmt`, so its own PR would revert every patch in this
#    file, including both of these. Running `make regen` instead reapplies them,
#    which makes the PR self-consistent.
#
# Idempotent, so running it twice is safe.
.PHONY: patch_resync_base
patch_resync_base:
	@if grep -q '^          base: master$$' .github/workflows/resync-build.yml; then \
		echo "resync-build.yml already targets master"; \
	else \
		perl -pi -e 's/^(          base: )main$$/$$1master/' .github/workflows/resync-build.yml; \
		grep -q '^          base: master$$' .github/workflows/resync-build.yml \
			&& echo "patched resync-build.yml to target master" \
			|| { echo "FAILED to patch resync-build.yml; the base line must have changed shape"; exit 1; }; \
	fi
	@if grep -q '^          make regen$$' .github/workflows/resync-build.yml; then \
		echo "resync-build.yml already runs make regen"; \
	else \
		perl -pi -e 's/^(          make )ci-mgmt$$/$${1}regen/' .github/workflows/resync-build.yml; \
		grep -q '^          make regen$$' .github/workflows/resync-build.yml \
			&& echo "patched resync-build.yml to run make regen" \
			|| { echo "FAILED to patch resync-build.yml; the regenerate step must have changed shape"; exit 1; }; \
	fi

# Use this instead of `make ci-mgmt`. The patches have to run after the
# generator, and make runs prerequisites before a target's recipe, so they
# cannot be hooked onto ci-mgmt directly.
.PHONY: regen
regen:
	$(MAKE) ci-mgmt
	$(MAKE) patch_resync_base

# `pulumi package publish-sdk` runs `npm publish` with no `--access` flag, so a
# scoped package would publish private. Runs before build_nodejs copies
# package.json into bin/.
.make/build_nodejs: .make/npm_public_access
.make/npm_public_access: .make/generate_nodejs
	cd sdk/nodejs && npm pkg set publishConfig.access="public"
	@touch $@
