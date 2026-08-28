import * as incident from "@incident-io/pulumi";

// Severity has no dependencies on other resources, which keeps the test
// cheap to set up and tear down against a real account.
const severity = new incident.Severity("basic", {
    name: "Basic",
    description: "Created by the pulumi-incident example test.",
    rank: 1,
});

export const severityId = severity.id;
