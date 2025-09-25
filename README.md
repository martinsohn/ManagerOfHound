# ManagerOfHound

ManagerOfHound is an [OpenGraph](https://bloodhound.specterops.io/opengraph/overview) extension for [BloodHound](https://bloodhound.specterops.io) that collect manager-subordinate relationships from Active Directory and exports them as custom "ManagerOf" edges for BloodHound ingestion.

Some organizations implement self-service portals where managers can control the user accounts of their subordinates (e.g. password resets). This can create implicit privilege escalation paths not captured by the default BloodHound edges. ManagerOfHound makes these hidden relationships visible through OpenGraph, enabling security teams to identify and assess novel attack paths in their environment.

Demonstration available in the [@SpecterOps #BloodHoundBasics post on X](https://x.com/SpecterOps/status/1969104194012406144)

<p align="center">
  <img width="800" alt="BloodHound's Explore page showing ManagerOf edges between User nodes" src="https://github.com/user-attachments/assets/3bb8447c-4620-4cf6-9d0e-e05bf2c0e129" />
</p>

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

### (OPTIONAL) Create demo edges if running the [GOAD lab](https://orange-cyberdefense.github.io/GOAD/)

Demo output from GOAD lab: [OpenGraph_ManagerOf_20250919110441.json](OpenGraph_ManagerOf_20250919110441.json)
```powershell
. .\Set-GOTManagerHierarchy.ps1
Set-GOTManagerHierarchy
```

#### Collect with default settings

```powershell
. .\ManagerOfHound.ps1

# Run with defaults:
# - Searches entire domain (all OUs)
# - Uses current domain controller
# - Saves to current directory
# - Output file: OpenGraph_ManagerOf_[timestamp].json
Invoke-ManagerOfHound
```

### Collect from Specific OU

```powershell
Invoke-ManagerOfHound -SearchBase "CN=Users,DC=north,DC=sevenkingdoms,DC=local"
```

### Output

Generates `OpenGraph_ManagerOf_[timestamp].json` containing:
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

## License

MIT License - See [LICENSE](LICENSE) for details.

## References

- [BloodHound OpenGraph Documentation](https://bloodhound.specterops.io/opengraph/overview)
- [OpenGraph Best Practices](https://bloodhound.specterops.io/opengraph/best-practices)
- [Active Directory Manager Attribute](https://docs.microsoft.com/en-us/windows/win32/adschema/a-manager)
