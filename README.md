# ManagerOfHound

Export Active Directory manager relationships to [BloodHound](https://bloodhound.specterops.io) via [OpenGraph](https://bloodhound.specterops.io/opengraph/overview).

## Overview

ManagerOfHound collects manager-subordinate relationships from Active Directory and exports them as custom "ManagerOf" edges for BloodHound ingestion.

Some organizations implement self-service portals where managers can control the user accounts of their subordinates. This can create implicit privilege escalation paths not captured by default BloodHound edges. ManagerOfHound makes these hidden relationships visible through OpenGraph, enabling security teams to identify and assess novel attack paths in their environment.

## Requirements

- PowerShell 3.0+
- Windows with .NET Framework
- Read access to the [Manager attribute](https://learn.microsoft.com/en-us/windows/win32/adschema/a-manager) of users (Authenticated Users has read by default)
- BloodHound v8.0 or above

## Usage

### Clone the repo
```powershell
git clone https://github.com/martinsohn/ManagerOfHound.git
cd ManagerOfHound
```

### Set up demo with [GOAD lab](https://orange-cyberdefense.github.io/GOAD/)
Demo output: [OpenGraph_ManagerOf_20250919110441.json](OpenGraph_ManagerOf_20250919110441.json)
```powershell
. .\Set-GOTManagerHierarchy.ps1
Set-GOTManagerHierarchy
```

### Collect with default settings
```powershell
. .\ManagerOfHound.ps1

# Run with defaults:
# - Searches entire domain (all OUs)
# - Uses current domain controller
# - Saves to current directory
# - Output file: OpenGraph_ManagerOf.json
Invoke-ManagerOfHound
```

### Collect from Specific OU
```powershell
Invoke-ManagerOfHound -SearchBase "CN=Users,DC=north,DC=sevenkingdoms,DC=local"
```

## Output

Generates `OpenGraph_ManagerOf.json` containing:
- Manager-to-subordinate relationships as "ManagerOf" edges
- Node identifiers using Active Directory SIDs
- Metadata for OpenGraph context

## Cypher Queries

### Find All Manager Relationships
```cypher
MATCH p=(:User)-[:ManagerOf]->(:User)
RETURN p
LIMIT 1000
```

### Find Tier Zero users with Managers
```cypher
MATCH p=(:User)-[:ManagerOf]->(n:User)
WHERE (n:Tag_Tier_Zero)
RETURN p
LIMIT 1000
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## License

MIT License - See [LICENSE](LICENSE) for details.

## References

- [BloodHound OpenGraph Documentation](https://bloodhound.specterops.io/opengraph/overview)
- [OpenGraph Best Practices](https://bloodhound.specterops.io/opengraph/best-practices)
- [Active Directory Manager Attribute](https://docs.microsoft.com/en-us/windows/win32/adschema/a-manager)
