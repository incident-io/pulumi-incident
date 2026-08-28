# pulumi-incident

A Pulumi provider for [incident.io](https://incident.io), bridged from
[`incident-io/terraform-provider-incident`](https://github.com/incident-io/terraform-provider-incident)
using the [Pulumi Terraform Bridge](https://github.com/pulumi/pulumi-terraform-bridge).

Its purpose is **distribution**. Pulumi can already drive our Terraform
provider today via `pulumi package add terraform-provider incident-io/incident`,
but that generates an SDK on the user's own machine and publishes no packages.
This repo produces pre-built SDKs on npm, PyPI, NuGet and the Go module proxy,
so incident.io installs like any other dependency.

The resource tokens generated here are **identical** to those the dynamically
bridged package already serves (`incident:index/alertRoute:AlertRoute` and so
on), so existing Pulumi users' programs keep working unchanged — with one
exception. `CatalogEntries` renames its `catalogEntriesId` input to
`catalogTypeId`, because the dynamic bridge's auto-generated name describes the
wrong thing. Anyone migrating from `pulumi package add` must rename that one
property.

## Status

Scaffold. It builds and generates a valid schema; it has never been published.

| | |
|---|---|
| Resources / functions | 23 / 19 |
| Upstream | `terraform-provider-incident` v6.8.0 |
| Bridge | `pulumi-terraform-bridge` v3.138.0 |
| Example conversion | 90.6% overall; 97% Python, 97% TypeScript |

## Two upstream changes are required before this can ship

Both live in `terraform-provider-incident`, and `provider/go.mod` currently
carries a filesystem `replace` to work around them.

### 1. Expose a non-internal shim

The provider implementation is under `internal/`, which Go forbids other
modules from importing. Upstream needs a small `shim/shim.go` exporting
`NewProvider(version string) provider.Provider` that returns
`internal/provider.New(version)()`.

The working copy of that file lives in the local upstream checkout the
`replace` points at. It is not duplicated here on purpose — one copy, so the
two cannot drift.

### 2. Add the `/v6` major-version suffix to the module path

Upstream is tagged `v6.8.0` but still declares the unsuffixed module path
`github.com/incident-io/terraform-provider-incident`. Go therefore rejects it:

```
go get github.com/incident-io/terraform-provider-incident@v6.8.0
  → invalid version: module contains a go.mod file, so module path must
    match major version (".../v6")
```

`@latest` resolves to **v1.4.2**, and the proxy serves nothing newer. The fix
is a one-line change to upstream's `go.mod` (`module github.com/incident-io/terraform-provider-incident/v6`).
It affects no Terraform user, since nobody imports a provider as a library.

Until then, `go get` can only reach current code via a commit pseudo-version,
which `upgrade-provider` automation cannot track.

### The better fix for both: an `upstream/` submodule

The absolute-path `replace` in `provider/go.mod` is machine-specific — nobody
else, CI included, can build from a clone. Pulumi's own bridged providers
(`pulumi-aws`, `pulumi-cloudflare`, `pulumi-datadog`) all solve exactly this
with a git submodule at `upstream/`, `replace ... => ../upstream`, and local
changes carried as `patches/*.patch` applied by `make upstream` — machinery
ci-mgmt generates. That fixes both problems above: the shim becomes a checked-in
patch that doubles as the upstream PR, and pinning a submodule SHA makes the
missing `/v6` suffix irrelevant. Worth moving to before this repo is shared.

## Building locally

Needs Go (1.26.7+, fetched automatically) and the `pulumi` CLI on `PATH` — the
CLI does the HCL→Pulumi example conversion, and tfgen **panics** without it
rather than degrading gracefully.

```bash
# Must match the path in provider/go.mod's replace directive.
export UPSTREAM_REPO_PATH=/path/to/terraform-provider-incident

make tfgen        # generate schema.json + bridge-metadata.json
make provider     # build the plugin binary
make build_sdks   # generate the four language SDKs
```

`UPSTREAM_REPO_PATH` is required because the bridge infers the upstream docs
location by shelling out to `go mod download -json`, which returns nothing for
a filesystem `replace`. Left unset, tfgen still succeeds — it just emits a
schema with no docs and no examples, which is why `make tfgen` refuses to run
without it. Setting it *wrongly* is worse than leaving it unset: a bad path
produces no error at all, just per-resource warnings and silently missing docs.

Once the submodule move above happens, this becomes the constant
`"./upstream"` in `resources.go` and the variable disappears.

## Publishing

Nothing here is published yet. Required accounts:

| Registry | Package | Status |
|---|---|---|
| npm | `@incident-io/pulumi` | Org already exists; needs an automation token |
| Go | `github.com/incident-io/pulumi-incident/sdk/go/...` | No account needed — published by pushing an `sdk/vX.Y.Z` tag |
| PyPI | `pulumi-incident` | New account + token; name unclaimed |
| NuGet | `IncidentIO.*` | New account + key. `Pulumi.*` is a reserved prefix owned by Pulumi Corp, so we cannot use `Pulumi.Incident` |

Registry listing is a PR to
[`pulumi/registry`](https://github.com/pulumi/registry) adding this repo to
`community-packages/package-list.json`, plus `docs/_index.md` and
`docs/installation-configuration.md`. Recent community listings merged
same-day.

## Known issues

- `logos/incident.svg` is referenced by `LogoURL` but not yet added, so the
  registry listing would render without an icon.
- tfgen warns `Failure in parsing resource name: incident_escalation_path,
  subsection: ## Schema`. That resource hand-unrolls its `if_else` recursion
  five levels deep and accounts for ~86% of the whole schema; its docs page is
  ~9,000 lines.
- 23 of 245 examples fail conversion, concentrated in Java and Go.
