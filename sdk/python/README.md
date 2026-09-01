# Pulumi provider for incident.io

Manage your incident.io configuration as code from a Pulumi program, in TypeScript, Python or Go.

Most teams end up configuring incident.io twice. Once by clicking through the dashboard to get set up, and then again every time a team reorganises, a new service ships, or someone joins the on-call rotation. Doing it by hand is fine until it isn't: you lose track of who changed what, staging and production drift apart, and onboarding a new team means repeating a dozen manual steps that live in someone's head.

This provider puts that configuration in the same place as the rest of your infrastructure. Your escalation paths, schedules, alert routes, catalog and custom fields become code you review, version and roll back like anything else.

If you already manage incident.io with Terraform, this is the same provider underneath. Everything you can do in [`terraform-provider-incident`](https://github.com/incident-io/terraform-provider-incident) works here, because this package is generated from it.

## Installing

```bash
# TypeScript / JavaScript
npm install @incident-io/pulumi

# Python
pip install pulumi-incident

# Go
go get github.com/incident-io/pulumi-incident/sdk/go/incident
```

## Configuring

The provider needs an API key. Create one in [Settings → API keys](https://app.incident.io/settings/api-keys), then either set it in your stack config:

```bash
pulumi config set --secret incident:apiKey inc_...
```

or export it as an environment variable:

```bash
export INCIDENT_API_KEY=inc_...
```

Stack config is usually the better choice, because it keeps the key encrypted in your Pulumi state alongside the program that uses it, and different stacks can point at different incident.io accounts.

If you are on a dedicated or self-hosted deployment, set `incident:endpoint` (or `INCIDENT_ENDPOINT`) to your API URL. Everyone else can leave it alone.

## An example

```typescript
import * as pulumi from "@pulumi/pulumi";
import * as incident from "@incident-io/pulumi";

// Create a Major severity with a default assigned rank.
const trivial = new incident.Severity("trivial", {
    name: "Trivial",
    description: "Issues causing no impact. No Immediate response is required.",
});
```

Every resource has examples in every supported language on the [Pulumi Registry page](https://www.pulumi.com/registry/packages/incident/), generated from the same source as our Terraform docs.

## What you can manage

23 resources and 19 data sources, covering:

- **On-call**: escalation paths, schedules, and schedule sync rules and targets that keep rotations in step with an external source of truth.
- **Alerts**: alert sources, alert routes, and the attributes you route on.
- **Catalog**: catalog types, their attributes, and entries. Useful for modelling your services and teams, and for driving routing decisions from that model.
- **Incident configuration**: severities, statuses, incident roles, custom fields and their options.
- **Automation**: workflows and maintenance windows.

Some resources are marked `Beta` in their name. Those track features still changing shape in the product, and their inputs may change in a minor release.

## Importing what you already have

You do not need to start from scratch. Every resource supports `pulumi import`, so you can bring existing configuration under management one piece at a time:

```bash
pulumi import incident:index/severity:Severity trivial 01ABCDEF...
```

Resources created or imported this way are tagged in incident.io as managed by code, so it is clear in the dashboard which configuration you should not edit by hand.

## Moving from the Terraform bridge

If you are currently using `pulumi package add terraform-provider incident-io/incident`, this package replaces it. The resource names and properties are identical, so your program does not change. Remove the `packages` entry from `Pulumi.yaml`, delete the locally generated SDK, and install the published package instead.

## Getting help

- [Pulumi Registry docs](https://www.pulumi.com/registry/packages/incident/) for per-resource reference and examples.
- [incident.io API docs](https://api-docs.incident.io/) for what the underlying API supports.
- Bugs and feature requests in [GitHub issues](https://github.com/incident-io/pulumi-incident/issues). If the problem is with a resource's behaviour rather than the Pulumi packaging, it probably belongs in [terraform-provider-incident](https://github.com/incident-io/terraform-provider-incident/issues) instead, since that is where the resources are implemented.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for how to build the provider and regenerate the SDKs.

## License

MIT. See [LICENSE](./LICENSE).
