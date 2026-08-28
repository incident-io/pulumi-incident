# Local additions. The generated Makefile ends with `include $(wildcard .mk/*.mk)`,
# so this file survives `make ci-mgmt`.

# ci-mgmt generates release.yml without a workflow_dispatch trigger, and
# regenerating drops the one we add by hand. incident-sync.yml tags with
# github.token, and GitHub refuses to start a workflow from a tag created that
# way, so without the trigger the tag lands and nothing ever publishes.
#
# Re-add it after every regeneration. Idempotent, so running it twice is safe.
.PHONY: patch_release_dispatch
patch_release_dispatch:
	@if grep -q 'workflow_dispatch' .github/workflows/release.yml; then \
		echo "release.yml already has workflow_dispatch"; \
	else \
		perl -0pi -e 's/(on:\n  push:\n    tags:\n    - v\*\.\*\.\*\n    - "!v\*\.\*\.\*-\*\*"\n)/$$1  # Added by .mk\/incident.mk. incident-sync.yml tags with github.token, and\n  # GitHub will not start a workflow from a tag created that way, so it\n  # dispatches this instead.\n  workflow_dispatch: {}\n/' .github/workflows/release.yml; \
		grep -q 'workflow_dispatch' .github/workflows/release.yml \
			&& echo "patched release.yml with workflow_dispatch" \
			|| { echo "FAILED to patch release.yml; the trigger block must have changed shape"; exit 1; }; \
	fi

# Use this instead of `make ci-mgmt`. The patch has to run after the generator,
# and make runs prerequisites before a target's recipe, so it cannot be hooked
# onto ci-mgmt directly.
#
# incident-sync.yml also checks the trigger is present and fails loudly if it is
# not, so forgetting this is noisy rather than silent.
.PHONY: regen
regen:
	$(MAKE) ci-mgmt
	$(MAKE) patch_release_dispatch
