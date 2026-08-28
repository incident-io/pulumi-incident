# Pulumi provider for incident.io

Manage incident.io configuration as code from a Pulumi program, in TypeScript, Python or Go.

Generated from [`terraform-provider-incident`](https://github.com/incident-io/terraform-provider-incident), so anything you can manage with Terraform you can manage here.

## Install

```bash
npm install @incident-io/pulumi
pip install pulumi-incident
go get github.com/incident-io/pulumi-incident/sdk/go/incident
```

## Configure

Create an API key in [Settings → API keys](https://app.incident.io/settings/api-keys), then either:

```bash
pulumi config set --secret incident:apiKey inc_...
# or
export INCIDENT_API_KEY=inc_...
```

On a dedicated or self-hosted deployment, also set `incident:endpoint`.

## Example

```typescript
import * as incident from "@incident-io/pulumi";

const trivial = new incident.Severity("trivial", {
    name: "Trivial",
    description: "Issues causing no impact.",
    rank: 1,
});
```

Per-resource reference and examples in all three languages are on the [Pulumi Registry page](https://www.pulumi.com/registry/packages/incident/).

## What you can manage

Escalation paths, schedules and schedule sync rules. Alert sources, routes and attributes. Catalog types, attributes and entries. Severities, statuses, incident roles, custom fields. Workflows, maintenance windows, policies, secrets and API keys.

Resources with `Beta` in the name track features still changing in the product, and their inputs may change in a minor release.

## Import existing configuration

Every resource supports `pulumi import`:

```bash
pulumi import incident:index/severity:Severity trivial 01ABCDEF...
```

Importing claims the resource as managed by code, which stops it being edited in the dashboard. That claim is a write to your account, so set `markImportedResourcesAsManaged` to `false` if you would rather imports left it untouched.

## Moving from the Terraform bridge

If you use `pulumi package add terraform-provider incident-io/incident` today, this package replaces it. Resource names and properties are the same, so your program does not change. Remove the `packages` entry from `Pulumi.yaml`, delete the generated SDK, and install the published package.

## Help

- [Registry docs](https://www.pulumi.com/registry/packages/incident/) for per-resource reference
- [API docs](https://api-docs.incident.io/) for what the underlying API supports
- [Issues](https://github.com/incident-io/pulumi-incident/issues) here for packaging problems, or [terraform-provider-incident](https://github.com/incident-io/terraform-provider-incident/issues) for resource behaviour, since that is where resources are implemented

[CONTRIBUTING.md](./CONTRIBUTING.md) covers building and regenerating the SDKs.

MIT licensed. See [LICENSE](./LICENSE).
