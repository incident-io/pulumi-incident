import pulumi
import pulumi_incident as incident

# Severity has no dependencies on other resources, which keeps the test cheap
# to set up and tear down against a real account.
severity = incident.Severity(
    "basic",
    name="Basic",
    description="Created by the pulumi-incident example test.",
    rank=1,
)

pulumi.export("severity_id", severity.id)
