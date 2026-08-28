This repository bridges the incident.io Terraform provider (`incident-io/terraform-provider-incident`) into a Pulumi provider, using `pulumi/pulumi-terraform-bridge`. It exists for **distribution**: Pulumi can already drive our Terraform provider via `pulumi package add terraform-provider incident-io/incident`, but that generates an SDK on the user's machine and publishes no packages. This repo publishes pre-built SDKs to npm, PyPI, NuGet and the Go module proxy.

People might make changes to:

- Map a new upstream resource, or fix how an existing one is bridged
- Bump the upstream provider or the bridge
- Wire up publishing

See also README.md, which covers the two unresolved upstream blockers.

# Development guidelines

## What is hand-written vs generated

Only these are hand-written: `provider/resources.go`, `provider/cmd/*/main.go`, `provider/pkg/version/version.go`, `Makefile`, `.ci-mgmt.yaml`, `.gitignore`. Everything else is generated and **must not be hand-edited**: `schema.json`, `bridge-metadata.json`, `Pulumi.yaml`, and everything under `sdk/`. Change `resources.go` and regenerate instead.

`schema.json` and `bridge-metadata.json` ARE committed — the Pulumi Registry fetches `schema.json` from the repo at a release tag. Expect large mechanical diffs on every upstream bump; that is normal.

## Building

```bash
export UPSTREAM_REPO_PATH=/path/to/terraform-provider-incident   # required, see below
make tfgen        # schema.json + bridge-metadata.json
make provider     # plugin binary
make build_sdks   # the four language SDKs
```

`tfgen` **panics** if the `pulumi` CLI is not on PATH — it shells out to it to convert upstream's HCL doc examples into per-language Pulumi examples. It does not degrade gracefully.

There are no tests yet. When adding them, use plain Go plus Pulumi's integration framework (`pulumi/pkg/v3/testing/integration`), driving a few simple resources (`incident_severity`, `incident_status`) plus one hard one (`incident_alert_route`) to catch diff-consistency problems. This is **not** the `core` monorepo — do not reach for ginkgo — and do not try to reuse upstream's acceptance suite, which needs a live org, runs single-threaded, and is pinned to Terraform 1.2.*.

## Verification

`make tfgen` is expensive (it converts ~245 doc examples across 7 languages). The Makefile uses `.make/` stamp files so a repeat build is a no-op — do not "fix" that by making targets phony. After changing `resources.go`, run `make tfgen` once and inspect the `schema.json` diff; that diff is the real test of a mapping change.

# Debugging

## Potential fixes for common issues

- **`bridge-metadata.json` replays past decisions, so changing an override in `resources.go` can silently do nothing.** `applyPrecomputedResourceFixups` replays what a previous tfgen run learned for each resource. If you change a `ResourceInfo` and regenerate, the stale decision can win with no warning. Reset the file to `{}` and regenerate to confirm what your change actually produces. This is not theoretical — it masked a real `ComputeID` fix until the file was reset.

- **Renaming a resource's `id` field disables the bridge's ID delegation.** Pulumi reserves `id` for the resource output id, so upstream resources that take `id` as an _input_ get auto-renamed by the `fixID` fixup, which also sets `ComputeID` to delegate to the renamed field. Supplying `SchemaInfo{Name: ...}` yourself makes `fixID` bail early and skip that, and `fixMissingID` then hands every instance the literal id `"missing ID"`. If you rename an `id`, set `ComputeID: tfbridge.DelegateIDField(...)` alongside it. `incident_catalog_entries` is the live example. Check your work in `bridge-metadata.json`: a `"computeID": {"kind": "missing"}` entry on a resource that has a real identifier is the bug.

- **`UPSTREAM_REPO_PATH` unset is loud; wrong is silent, and worse.** The bridge finds upstream's docs by shelling out to `go mod download -json`, which returns nothing while `provider/go.mod` carries a filesystem `replace`. Unset, you get one `GetRepoPathErr` warning and a schema with no docs and no examples. Set to a _wrong_ path, `getRepoPath` never runs, so there is no error at all — just per-resource "could not find docs" warnings and silently missing documentation. Set to a _stale but valid_ checkout, docs are generated from the wrong provider version with no warning whatsoever. The Makefile hard-fails on unset for this reason. Always sanity-check the example conversion rate in tfgen's output (currently ~90%); a sudden drop to 0% means the docs path broke.

- **`.ci-mgmt.yaml` typos are hard errors that generate nothing.** The config is decoded with `KnownFields(true)`, so an unknown key aborts generation entirely rather than being ignored. Keys are inconsistently cased — `major-version` is kebab, `providerDefaultBranch` and `upstreamProviderOrg` are camel. Validate against `provider-ci/internal/pkg/config.go` rather than guessing, and run the generator to confirm.

- **Use `pulumi-labs/ci-mgmt`, never `pulumi/ci-mgmt`.** Upstream refuses non-Pulumi orgs, and does it by printing a redirect notice and returning **exit 0** — so it looks like a successful no-change run. It also hardcodes Pulumi's own ESC organization for OIDC, so its output cannot authenticate from our repo even if you bypass the org check.

- **The `Makefile` is a placeholder.** ci-mgmt generates the real one (~300 lines, with crossbuild, per-language SDK builds, and the targets the release workflows call). The first successful `provider-ci generate` overwrites what is here. Put local additions in `.mk/*.mk`, which the generated Makefile includes — do not grow this file.

- **`tfgen` does not rewrite `schema.json` when the content is unchanged**, so its mtime can be older than the binary that produced it. Any Make dependency chain that keys on `schema.json` directly will therefore rebuild forever. This is why the schema step is stamped at `.make/schema`.

- **Upstream's module path has no `/v6` suffix** despite being tagged v6.x, so `go get` rejects every modern version and `@latest` resolves to v1.4.2. `provider/go.mod` currently works around this with a machine-specific absolute-path `replace`, which means a fresh clone cannot build. The proper fix is the `upstream/` git submodule + `patches/` layout every Pulumi bridged provider uses; see README.md.

- **Do not add per-resource token mappings.** `tokens.SingleModule` + `MakeStandard` maps all of them, and produces tokens identical to the dynamically bridged package already on the Pulumi Registry — which is what stops existing users' programs breaking. Adding manual tokens risks diverging from that.
