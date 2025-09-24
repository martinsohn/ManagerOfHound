function Set-GOTManagerHierarchy {
    <#
    .SYNOPSIS
        Configures Game of Thrones inspired manager relationships in Active Directory.
    
    .DESCRIPTION
        Sets up a hierarchical manager structure based on Game of Thrones characters
        for testing BloodHound's ManagerOf edge detection with Invoke-ManagerOfHound.
        Designed to work with the GOAD (Game of Thrones AD) lab environment.
    
    .EXAMPLE
        Set-GOTManagerHierarchy
        Sets up all GoT manager relationships and displays a summary
    
    .NOTES
        Requires: Active Directory PowerShell module and appropriate permissions
        Compatible with: GOAD lab (https://orange-cyberdefense.github.io/GOAD/)
    #>
    
    [CmdletBinding()]
    param()
    
    # Define the management hierarchy based on GoT relationships
    $managerRelationships = @(
        # House Stark - Eddard is head of household
        @{Manager = "eddard.stark"; Subordinate = "robb.stark"},      # Father -> Eldest son
        @{Manager = "eddard.stark"; Subordinate = "sansa.stark"},     # Father -> Daughter
        @{Manager = "eddard.stark"; Subordinate = "arya.stark"},      # Father -> Daughter
        @{Manager = "eddard.stark"; Subordinate = "brandon.stark"},   # Father -> Son
        @{Manager = "eddard.stark"; Subordinate = "rickon.stark"},    # Father -> Son
        @{Manager = "eddard.stark"; Subordinate = "jon.snow"},        # Father figure -> Bastard
        
        # Catelyn manages household staff
        @{Manager = "catelyn.stark"; Subordinate = "hodor"},          # Lady -> Servant
        
        # Night's Watch hierarchy
        @{Manager = "jeor.mormont"; Subordinate = "jon.snow"},        # Lord Commander -> Recruit
        @{Manager = "jon.snow"; Subordinate = "samwell.tarly"}       # Jon -> Sam (later Jon becomes Lord Commander)
    )
    
    # Import AD module
    try {
        Import-Module ActiveDirectory -ErrorAction Stop -Verbose:$false
    } catch {
        Write-Error "Failed to load Active Directory module"
        return
    }
    
    # Process each relationship
    $successCount = 0
    $errorCount = 0
    
    foreach ($relationship in $managerRelationships) {
        try {
            # Get manager DN
            $managerUser = Get-ADUser -Identity $relationship.Manager -ErrorAction Stop
            $managerDN = $managerUser.DistinguishedName
            
            # Set subordinate's manager
            Set-ADUser -Identity $relationship.Subordinate -Manager $managerDN -ErrorAction Stop
            
            Write-Verbose "Set $($relationship.Manager) as manager of $($relationship.Subordinate)"
            $successCount++
        } catch {
            Write-Warning "Failed to set $($relationship.Manager) as manager of $($relationship.Subordinate): $_"
            $errorCount++
        }
    }
    
    # Build summary
    $summary = @"

Game of Thrones Manager Hierarchy Configuration Complete
=========================================================
Successfully configured: $successCount relationships
Failed: $errorCount relationships
"@
    
    Write-Host $summary -ForegroundColor Cyan
    
    # Verify the hierarchy
    Write-Host "`nVerifying Manager Hierarchy:" -ForegroundColor Yellow
    Write-Host "=============================" -ForegroundColor Yellow
    
    $usersWithManagers = Get-ADUser -LDAPFilter "(manager=*)" -Properties Manager -ErrorAction SilentlyContinue
    
    if ($usersWithManagers) {
        $managers = @{}
        
        foreach ($user in $usersWithManagers) {
            $managerDN = $user.Manager
            $manager = Get-ADUser -Identity $managerDN -ErrorAction SilentlyContinue
            
            if ($manager) {
                if (-not $managers.ContainsKey($manager.SamAccountName)) {
                    $managers[$manager.SamAccountName] = @()
                }
                $managers[$manager.SamAccountName] += $user.SamAccountName
            }
        }
        
        # Display hierarchy tree
        foreach ($manager in $managers.Keys | Sort-Object) {
            Write-Host "`n👑 $manager" -ForegroundColor Yellow
            foreach ($subordinate in $managers[$manager] | Sort-Object) {
                Write-Host "   └─ $subordinate" -ForegroundColor Cyan
            }
        }
        
        Write-Host "`nTotal verified relationships: $($usersWithManagers.Count)" -ForegroundColor Green
    } else {
        Write-Host "No manager relationships found in AD" -ForegroundColor Red
    }
    
    # Return summary statistics
    return @{
        Success = $successCount
        Failed = $errorCount
        TotalRelationships = $managerRelationships.Count
    }
}