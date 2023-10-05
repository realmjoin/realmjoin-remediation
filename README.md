# realmjoin-remediation
Repository for generic Intune Proactive Remediation Scripts that can be easily provisioned via RealmJoin portal into individual tenants.

## Generic template
Please see our [generic template](/template/detect-and-remediate) as a guideline for new scripts:
- README.md: description and additional hints (mandatory)
- config.json: meta data needed for provisioning scripts (mandatory)
- Detect.ps1: detection script (mandatory)
- Remediate.ps1: remediation script (optional)