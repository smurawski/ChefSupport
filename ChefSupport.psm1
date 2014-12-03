
$WinRMSettings = @{
    ProviderPath = 'WSMan:\localhost'
    Base = @{
        MaxBatchItems = @{
            MinimumValue = 20
            RecommendedValue = 32000
        }
        MaxEnvelopeSizekb = @{
            MinimumValue = 150
            RecommendedValue = 500 
        }
        MaxProviderRequests = @{
            MinimumValue = 25
            RecommendedValue = 4294967295
        }
        MaxTimeoutms = @{
            MinimumValue = 60000
            RecommendedValue = 1800000
        }
    }
    Service = @{
        ProviderPath = 'WSMan:\localhost\Service'
        Base = @{
            AllowUnencrypted = @{ RecommendedValue = $true }
            MaxConcurrentOperations = @{
               MinimumValue = 100
               RecommendedValue = 4294967295 
            }
            MaxConcurrentOperationsPerUser = @{
                MinimumValue = 15
                RecommendedValue = 1500
            }
            MaxConnections = @{
                MinimumValue = 25
                RecommendedValue = 300
            }
        }
        Auth = @{
            ProviderPath = 'WSMan:\localhost\Service\Auth'    
            Base = @{
                Basic = @{}                
                Kerberos = @{}
                Negotiate = @{}
                CredSSP = @{}
                Certificate = @{}
            }
        }
        DefaultPorts = @{
            ProviderPath = 'WSMan:\localhost\Service\DefaultPorts'    
            Base = @{
                HTTP = @{ RecommendedValue = 5985 }
                HTTPS = @{ RecommendedValue = 5986 }
            }
        }
    }
    Shell = @{
        ProviderPath = 'WSMan:\localhost\Shell' 
        Base = @{
            IdleTimeout = @{
                MinimumValue = 180000
                RecommendedValue = 7200000
            }
            MaxConcurrentUsers = @{
                RecommendedValue = 10
            }
            MaxShellsPerUser = @{
                RecommendedValue = 30
            }
            MaxProcessesPerShell = @{
                RecommendedValue = 25
            }
            MaxMemoryPerShellMB = @{
                RecommendedValue =  1024
            }
        }
    }
}

function Test-WinRMConfiguration
{
    [cmdletbinding()]    
    param (
        [ValidateSet('All', 'None', 'LinuxOrMac', 'Windows')]
        [string[]]
        $RuleSet = 'None'
    )    
    $script:CurrentState = Get-WinRMConfiguration
    
    $IsValid = (Test-WinRMServiceState)
    $IsValid = $IsValid -and (Test-WinRMBaseConfiguration)
    $IsValid = $IsValid -and (Test-WinRMServiceConfiguration)
    $IsValid = $IsValid -and (Test-WinRMServiceAuthConfiguration)
    $IsValid = $IsValid -and (Test-WinRMServiceDefaultPortsConfiguration)
    $IsValid = $IsValid -and (Test-WinRMShellConfiguration)
    
    if ((($RuleSet.Count -eq 1) -and 
            ($RuleSet[0] -notlike 'None')) -or 
        ($RuleSet.Count -gt 1))
    {
        $IsValid | 
            Add-Member -MemberType NoteProperty -Name TestResults -value (Test-WinRMRuleSet -RuleSet $RuleSet)
    }

    return $IsValid
}

function Test-LinuxOrMacRuleSet
{
    [cmdletbinding()]
    param ($CurrentResult)

    $LinuxOrMacRuleSet = @{}
    
    $LinuxOrMacRuleSet.BasicAuthEnabled = $CurrentState.Service.Auth.Basic.CurrentValue
    $LinuxOrMacRuleSet.AllowUnencryptedEnabled = $CurrentState.Service.AllowUnencrypted.CurrentValue

    $LinuxOrMacRuleSet.IsValid = $true
    foreach ($key in $LinuxOrMacRuleSet.Keys) 
    {
        if (($key -notlike 'IsValid') -and $LinuxOrMacRuleSet.IsValid )
        {
            $LinuxOrMacRuleSet.IsValid = $LinuxOrMacRuleSet[$key]
        }
    }
    $CurrentResult.LinuxOrMacRuleSet = New-CustomObject -TypeName Chef.WinRM.TestResult.LinuxOrMacRuleSet -PropertyHashtable $LinuxOrMacRuleSet
    return $CurrentResult
}

function Test-WinRMRuleSet 
{
    param (
        [cmdletbinding()]  
        [ValidateSet('All', 'None', 'LinuxOrMac', 'Windows')]
        [string[]]
        $RuleSet
    )

    $Result = @{}
    switch ($RuleSet)
    {
        {('LinuxOrMac', 'All') -contains $_ } { $Result = Test-LinuxOrMacRuleSet -CurrentResult $Result }
        {('Windows', 'All') -contains $_ } { $Result = Test-WindowsRuleSet -CurrentResult $Result }
        default {}
    }
    return (New-CustomObject -TypeName Chef.WinRM.TestResult -PropertyHashtable $Result)
}

function Test-WindowsRuleSet 
{
}

function Test-WinRMServiceState
{
    [cmdletbinding()]
    param ()
    Get-WinRMServiceState
}

function Test-WinRMBaseConfiguration
{
    [cmdletbinding()]
    param ()
    Test-WinRMSetting -SettingRoot $WinRMSettings -CurrentRoot $CurrentState
}

function Test-WinRMServiceConfiguration
{
    [cmdletbinding()]
    param ()
    Test-WinRMSetting -SettingRoot $WinRMSettings.Service -CurrentRoot $CurrentState.Service
}

function Test-WinRMServiceAuthConfiguration
{
    [cmdletbinding()]
    param ()
    Test-WinRMSetting -SettingRoot $WinRMSettings.Service.Auth -CurrentRoot $CurrentState.Service.Auth
}

function Test-WinRMServiceDefaultPortsConfiguration
{
    [cmdletbinding()]
    param ()
    Test-WinRMSetting -SettingRoot $WinRMSettings.Service.DefaultPorts -CurrentRoot $CurrentState.Service.DefaultPorts
}

function Test-WinRMShellConfiguration
{
    [cmdletbinding()]
    param ()  
    Test-WinRMSetting -SettingRoot $WinRMSettings.Shell -CurrentRoot $CurrentState.Shell
}

function Test-WinRMSetting
{
    [cmdletbinding()]
    param ($SettingRoot, $CurrentRoot)

    $IsValid = $true
    foreach ($key in $SettingRoot.Base.Keys)
    {
        $CurrentRootSetting = $CurrentRoot.psobject.Properties[$key]
        Write-Verbose "Current Setting is $key"
        
        if ($CurrentRootSetting -ne $null) 
        {
            Write-Verbose "`t$($CurrentRootSetting.Name) is not null"
            $CurrentRootSetting = $CurrentRootSetting.Value
            if ($CurrentRootSetting.psobject.properties['MinimumValue'])
            {
                Write-Verbose "`t`tCurrent Value is - $($CurrentRootSetting.CurrentValue)"
                Write-Verbose "`t`tMinimum Value is - $($SettingRoot.Base[$key].MinimumValue)"
                $IsValid = $IsValid -and ($CurrentRootSetting.CurrentValue -ge $SettingRoot.Base[$key].MinimumValue)
            }
        } 
    }
    return $IsValid
}

function Get-WinRMShell
{    
    $CustomObjectProperties = @{
        TypeName = 'Chef.WinRM.Shell'
        PropertyHashtable = (Get-WinRMSetting $WinRMSettings.Shell)
    }
    New-CustomObject @CustomObjectProperties 
}

function Get-WinRMServiceAuthConfiguration
{
    $CustomObjectProperties = @{
        TypeName = 'Chef.WinRM.Service.Auth'
        PropertyHashtable = (Get-WinRMSetting $WinRMSettings.Service.Auth)
    }
    New-CustomObject @CustomObjectProperties
}

function Get-WinRMServiceDefaultPorts
{
    $CustomObjectProperties = @{
        TypeName = 'Chef.WinRM.Service.DefaultPorts'
        PropertyHashtable = (Get-WinRMSetting $WinRMSettings.Service.DefaultPorts)
    }
    New-CustomObject @CustomObjectProperties
}

function Get-WinRMServiceConfiguration 
{
    $CustomObjectProperties = @{
        TypeName = 'Chef.WinRM.Service'
        PropertyHashtable = (Get-WinRMSetting $WinRMSettings.Service) + @{
            Auth =         Get-WinRMServiceAuthConfiguration
            DefaultPorts = Get-WinRMServiceDefaultPorts    
        }
    }
    New-CustomObject @CustomObjectProperties
}

function Get-WinRMServiceState
{
    param ([string]$State = 'Running')

    $WinRMService = Get-Service WinRM
    if ($WinRMService.Status -like 'Running')
    {
        return $true        
    }
    else
    {
        return $false
    }    
}

function Get-WinRMConfiguration
{
    $CustomObjectProperties = @{
        TypeName = 'Chef.WinRM.Service'
        PropertyHashtable = (Get-WinRMSetting $WinRMSettings) + @{
            IsRunning = Get-WinRMServiceState
            Service =   Get-WinRMServiceConfiguration
            Shell =     Get-WinRMShell
            #Listener = @{}    
        }
    }
    New-CustomObject @CustomObjectProperties
}

function Get-WinRMSetting
{
    param (
        $SettingRoot
    )
    $PropertyHashTable = @{}
    foreach ($key in $SettingRoot.Base.Keys) 
    {
        $PropertyHashTable.Add( 
            $key, 
            (Get-WinRMConfiguredValue -Name $key -ProviderPath $SettingRoot.ProviderPath)
        )
    }
    return $PropertyHashTable
}

function Get-WinRMConfiguredValue 
{
    param (
        $Name,
        $Path, 
        $ProviderPath = 'WSman:\localhost',
        $BaseTypeName = 'Chef.WinRM', 
        $MinimumValue, 
        $RecommendedValue, 
        $Message
    )

    if (-not ($PSBoundParameters.ContainsKey('Path')))
    {   
        $PSBoundParameters.Remove('ProviderPath') | Out-Null        
             
        $Path = join-path $ProviderPath $Name

        $PSBoundParameters.Add('Path', $Path)
    }

    foreach ($key in ('Name','ProviderPath','BaseTypeName')) 
    {
        if ($PSBoundParameters.ContainsKey($key))
        {
            $PSBoundParameters.Remove($key) | out-null
        }
    }

    $PSBoundParameters.Add(
        'CurrentValue', 
        (get-item $Path).Value
    ) | Out-Null

    $PSBoundParameters.Remove('ProviderPath') | Out-Null  
    
    New-CustomObject -TypeName "$BaseTypeName.$Name" -PropertyHashtable $PSBoundParameters
}

function New-CustomObject 
{
    param ($TypeName = 'Chef', $PropertyHashtable)
    
    $OutputObject = New-Object PSObject -Property $PropertyHashtable
    $OutputObject.psobject.typenames.insert(0,$TypeName)
    $OutputObject
}

