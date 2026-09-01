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
| Upstream | `terraform-provider-incident` v6.9.0 |
| Bridge | `pulumi-terraform-bridge` v3.138.0 |
| Example conversion | 90.6% overall; 97% Python, 97% TypeScript |

## Upstream dependency

This imports `terraform-provider-incident` at its `/v6` module path, using
`shim.NewProvider` — a small non-internal package upstream exposes because Go
forbids importing another module's `internal/`. Both of those landed upstream in
August 2026, so there is no `replace` directive and a fresh clone builds.

`provider/go.mod` pins the released tag **v6.9.0** — the first release carrying
both changes — so `upgrade-provider` can track upstream by tag as normal.

Note that v6.8.0 and earlier are not usable: they predate the module-path change,
and the Go proxy rejects them with `go.mod has non-.../v6 module path`.

## Building locally

Needs Go (1.26.7+, fetched automatically) and the `pulumi` CLI on `PATH` — the
CLI does the HCL→Pulumi example conversion, and tfgen **panics** without it
rather than degrading gracefully.

```bash
make tfgen        # generate schema.json + bridge-metadata.json
make provider     # build the plugin binary
make build_sdks   # generate the four language SDKs
```

The bridge locates upstream's docs in the Go module cache from `GitHubOrg` and
`TFProviderModuleVersion` in `resources.go`. Get `TFProviderModuleVersion` wrong
— including leaving it empty, which makes the bridge look up the unsuffixed
module path — and tfgen still succeeds, silently emitting a schema with no docs
and no examples. Watch the example-conversion rate in tfgen's output; it should
be ~90%, and 0% means the docs lookup broke.

This is the field to bump when upstream crosses to v7.

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
