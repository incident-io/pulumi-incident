// Package incident bridges the incident.io Terraform provider into a Pulumi
// provider.
//
// The upstream provider is built on terraform-plugin-framework and speaks
// protocol 6 only, so this uses the bridge's plugin-framework path
// (pkg/pf/tfbridge) rather than the SDKv2 shim, and needs no muxing.
package incident

import (
	"path"

	// Allow embedding bridge-metadata.json in the provider.
	_ "embed"

	incidentshim "github.com/incident-io/terraform-provider-incident/v6/shim"

	pf "github.com/pulumi/pulumi-terraform-bridge/v3/pkg/pf/tfbridge"
	"github.com/pulumi/pulumi-terraform-bridge/v3/pkg/tfbridge"
	"github.com/pulumi/pulumi-terraform-bridge/v3/pkg/tfbridge/tokens"

	"github.com/incident-io/pulumi-incident/provider/pkg/version"
)

// The upstream provider is MIT licensed. Without this the bridge defaults to
// MPL 2.0 and stamps that into every generated SDK's README.
var upstreamLicense = tfbridge.MITLicenseType

// bridgeMetadata persists the computed token map and auto-alias ledger between
// tfgen runs. The plugin-framework bridge requires it, and it is what stops a
// later regeneration from silently renaming a resource out from under users.
//
// It also replays the default fixups a previous run decided on. Changing an
// override below therefore has no effect until this file is reset to `{}` and
// regenerated — the stale decision wins, silently.
//
//go:embed cmd/pulumi-resource-incident/bridge-metadata.json
var bridgeMetadata []byte

const (
	mainPkg = "incident"
	mainMod = "index"
	// githubOrg owns both this repo and the upstream Terraform provider.
	githubOrg = "incident-io"
)

// Provider returns the bridged provider definition.
func Provider() tfbridge.ProviderInfo {
	prov := tfbridge.ProviderInfo{
		P:            pf.ShimProvider(incidentshim.NewProvider(version.Version)),
		Name:         "incident",
		Version:      version.Version,
		DisplayName:  "incident.io",
		Publisher:    githubOrg,
		LogoURL:      "https://raw.githubusercontent.com/incident-io/pulumi-incident/master/logos/incident.svg",
		Description:  "A Pulumi package for managing incident.io resources.",
		Keywords:     []string{"pulumi", "incident", githubOrg, "category/cloud"},
		License:      "MIT",
		Homepage:     "https://incident.io",
		Repository:   "https://github.com/incident-io/pulumi-incident",
		MetadataInfo: tfbridge.NewProviderMetadata(bridgeMetadata),

		TFProviderLicense: &upstreamLicense,

		// Together these locate the upstream provider's markdown in the Go module
		// cache, which is what lets tfgen convert its HCL examples into
		// per-language Pulumi ones. Omitting the module version makes the bridge
		// look up the unsuffixed module path, which does not exist — and the only
		// symptom is a schema with no docs and no examples.
		GitHubOrg:               githubOrg,
		TFProviderModuleVersion: "v6",

		// Binaries are published as GitHub release assets rather than to
		// Pulumi's CDN, which is only available to Pulumi-internal providers.
		PluginDownloadURL: "github://api.github.com/incident-io/pulumi-incident",

		Config: map[string]*tfbridge.SchemaInfo{
			// Upstream reads INCIDENT_API_KEY itself when the config value is
			// null, so this changes no behaviour. It is declared purely so the
			// variable shows up in the generated SDKs and registry docs.
			//
			// Deliberately not mirrored for `endpoint`: upstream gives
			// INCIDENT_ENDPOINT precedence *over* the configured value, so a
			// Pulumi-side default there would be silently ignored.
			"api_key": {
				Default: &tfbridge.DefaultInfo{
					EnvVars: []string{"INCIDENT_API_KEY"},
				},
			},
		},

		JavaScript: &tfbridge.JavaScriptInfo{
			PackageName:          "@incident-io/pulumi",
			RespectSchemaVersion: true,
		},
		Python: &tfbridge.PythonInfo{
			PackageName:          "pulumi_incident",
			RespectSchemaVersion: true,
			PyProject:            struct{ Enabled bool }{true},
		},
		Golang: &tfbridge.GolangInfo{
			// Derived rather than hardcoded: from v2 the Go SDK module path has
			// to carry a major-version segment, and a literal would silently
			// publish an import path that does not resolve.
			ImportBasePath: path.Join(
				"github.com/incident-io/pulumi-incident/sdk/",
				tfbridge.GetModuleMajorVersion(version.Version),
				"go",
				mainPkg,
			),
			GenerateResourceContainerTypes: true,
			RespectSchemaVersion:           true,
		},
		CSharp: &tfbridge.CSharpInfo{
			// `Pulumi.*` is a reserved prefix on NuGet owned by Pulumi Corp, so
			// third-party packages use their own.
			RootNamespace:        "IncidentIO",
			RespectSchemaVersion: true,
			// Wildcard so NuGet resolves the newest compatible Pulumi rather
			// than pinning whatever version codegen happened to see.
			PackageReferences: map[string]string{"Pulumi": "3.*"},
		},
	}

	// Maps every `incident_*` type onto `incident:index/<resource>:<Resource>`
	// with no per-resource configuration. This produces tokens identical to the
	// dynamically bridged package already on the Pulumi Registry, so existing
	// users' programs keep working unchanged.
	prov.MustComputeTokens(tokens.SingleModule("incident_", mainMod, tokens.MakeStandard(mainPkg)))
	prov.MustApplyAutoAliases()
	prov.SetAutonaming(255, "-")

	return prov
}
