function Invoke-ManagerOfHound {
    <#
    .SYNOPSIS
        Exports Active Directory manager-subordinate relationships to OpenGraph JSON format.
    
    .DESCRIPTION
        Retrieves all Active Directory users with assigned managers and exports the hierarchical 
        relationships in OpenGraph JSON format suitable for graph visualization or analysis tools.
        Uses .NET DirectoryServices for better performance and no module dependencies.
    
    .PARAMETER OutputPath
        Path where the JSON output file will be saved. Defaults to current directory.
    
    .PARAMETER FileName
        Name of the output file. If not specified, defaults to 'OpenGraph_ManagerOf_[timestamp].json' 
        where timestamp is in format yyyyMMddHHmmss.
    
    .PARAMETER SearchBase
        Distinguished Name of the OU to search. If not specified, searches entire domain.
    
    .PARAMETER Server
        Domain Controller to query. If not specified, uses default DC.
    
    .PARAMETER PassThru
        Returns the graph object in addition to saving the file.
    
    .EXAMPLE
        Invoke-ManagerOfHound
        Exports all manager relationships to current directory
    
    .EXAMPLE
        Invoke-ManagerOfHound -OutputPath "C:\Reports" -SearchBase "OU=Sales,DC=contoso,DC=com"
        Exports manager relationships only from Sales OU to C:\Reports\OpenGraph_ManagerOf.json
    #>
    
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter()]
        [ValidateScript({
            if ($_ -and -not (Test-Path -Path $_ -PathType Container)) {
                throw "Directory '$_' does not exist"
            }
            return $true
        })]
        [string]$OutputPath,
        
        [Parameter()]
        [ValidatePattern('\.json$')]
        [string]$FileName,
        
        [Parameter()]
        [string]$SearchBase,
        
        [Parameter()]
        [string]$Server,
        
        [Parameter()]
        [switch]$PassThru
    )
    
    begin {
        # Add .NET types
        Add-Type -AssemblyName System.DirectoryServices
        
        # Use current location if OutputPath not specified
        if (-not $OutputPath) {
            $OutputPath = (Get-Location).Path
        }
        
        # Handle filename - add timestamp if using default name
        if (-not $FileName) {
            # Generate timestamp in format: yyyyMMddHHmmss
            $timestamp = Get-Date -Format "yyyyMMddHHmmss"
            $FileName = "OpenGraph_ManagerOf_$timestamp.json"
        }
        
        # Build output file path
        $outputFile = Join-Path -Path $OutputPath -ChildPath $FileName
        
        # Build LDAP path
        if ($SearchBase) {
            $ldapPath = "LDAP://$SearchBase"
        } else {
            # Get current domain
            $currentDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
            $ldapPath = "LDAP://$($currentDomain.Name)"
        }
        
        if ($Server) {
            $ldapPath = "LDAP://$Server/$SearchBase"
        }
        
        Write-Verbose "LDAP Path: $ldapPath"
    }
    
    process {
        # Initialize collections
        $edges = New-Object System.Collections.ArrayList
        
        # Create DirectorySearcher
        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $searcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry($ldapPath)
        $searcher.PageSize = 1000
        $searcher.Filter = "(&(objectCategory=person)(objectClass=user)(manager=*))"
        
        # Only load required properties
        [void]$searcher.PropertiesToLoad.Add("objectSid")
        [void]$searcher.PropertiesToLoad.Add("manager")
        [void]$searcher.PropertiesToLoad.Add("distinguishedName")
        
        Write-Verbose "Searching for users with managers..."
        
        # Execute search
        $results = $searcher.FindAll()
        
        if ($results.Count -eq 0) {
            Write-Warning "No users found with manager assignments"
            $results.Dispose()
            $searcher.Dispose()
            return
        }
        
        Write-Verbose "Found $($results.Count) users with managers"
        
        # Cache for manager lookups to avoid redundant queries
        $managerCache = @{}
        
        foreach ($result in $results) {
            try {
                # Get user SID
                $userSidBytes = $result.Properties["objectSid"][0]
                $userSid = (New-Object System.Security.Principal.SecurityIdentifier($userSidBytes, 0)).Value
                
                # Get manager DN
                $managerDN = $result.Properties["manager"][0]
                
                # Check cache first
                if ($managerCache.ContainsKey($managerDN)) {
                    $managerSid = $managerCache[$managerDN]
                } else {
                    # Look up manager's SID
                    $managerEntry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$managerDN")
                    $managerSidBytes = $managerEntry.Properties["objectSid"].Value
                    
                    if ($managerSidBytes) {
                        $managerSid = (New-Object System.Security.Principal.SecurityIdentifier($managerSidBytes, 0)).Value
                        $managerCache[$managerDN] = $managerSid
                    } else {
                        Write-Verbose "Could not get SID for manager: $managerDN"
                        $managerEntry.Dispose()
                        continue
                    }
                    
                    $managerEntry.Dispose()
                }
                
                # Create edge
                [void]$edges.Add(@{
                    kind = "ManagerOf"
                    start = @{
                        value = $managerSid
                        match_by = "id"
                    }
                    end = @{
                        value = $userSid
                        match_by = "id"
                    }
                })
                
            } catch {
                Write-Verbose "Error processing user: $_"
            }
        }
        
        # Clean up
        $results.Dispose()
        $searcher.Dispose()
        
        # Build final JSON structure
        $finalJson = @{
            metadata = @{
                source_kind = "ManagerOf"
            }
            graph = @{
                nodes = @()
                edges = $edges
            }
        }
        
        # Save JSON file
        $finalJson | ConvertTo-Json -Depth 4 -Compress | Out-File -Encoding UTF8 $outputFile
        
        Write-Host "Export complete: $outputFile"
        Write-Host "Processed $($edges.Count) edges"
        
        # Return object if requested
        if ($PassThru) {
            return $finalJson
        }
    }
}