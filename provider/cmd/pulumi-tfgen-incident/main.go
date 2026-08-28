// pulumi-tfgen-incident generates the Pulumi Package Schema and the
// per-language SDKs from the bridged Terraform provider.
package main

import (
	"github.com/pulumi/pulumi-terraform-bridge/v3/pkg/pf/tfgen"

	incident "github.com/incident-io/pulumi-incident/provider"
)

func main() {
	tfgen.Main("incident", incident.Provider())
}
