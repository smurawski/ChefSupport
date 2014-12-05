
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
    Listener = @{
        ProviderPath = 'WSMan:\localhost\Listener'
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
            Add-Member -MemberType NoteProperty -Name TestResults -value (Invoke-WinRMRuleSet -RuleSet $RuleSet)
    }

    return $IsValid
}

function Invoke-LinuxOrMacRuleSet
{
    [cmdletbinding()]
    param ($CurrentState = $script:CurrentState)

    $Rules = @{
        LocalAccountLoginEnabled  =  { ($CurrentState.Service.Auth.Basic.CurrentValue -and
                                        $CurrentState.Service.AllowUnencrypted.CurrentValue) -or 
                                        ($CurrentState.Service.Auth.Negotiate.CurrentValue)  }
        DomainAccountLoginEnabled =  { $CurrentState.Service.Auth.Negotiate.CurrentValue -and 
                                        $CurrentState.Listener.HTTPS.CurrentValue } 
        OnlySecureTrafficEnabled  =  { (-not $CurrentState.Service.AllowUnencrypted.CurrentValue) -and 
                                        (-not $CurrentState.Listener.HTTP.CurrentValue) -and 
                                        $CurrentState.Listener.HTTPS.CurrentValue } 
        PlaintextTrafficAvailable =  { $CurrentState.Listener.HTTP.CurrentValue -and 
                                        $CurrentState.Service.AllowUnencrypted.CurrentValue }
        SecureTrafficAvailable    =  { $CurrentState.Listener.HTTPS.CurrentValue }  
    }

    $LinuxOrMacRuleSet = @{}
    foreach ($key in $Rules.Keys)
    {  
        Write-Verbose "Processing $key in the LinuxOrMac Rule Set"
        $LinuxOrMacRuleSet.Add($key, ($rules[$key]).Invoke())  | Out-Null       
    }

    return (New-CustomObject -TypeName Chef.WinRM.TestResult.LinuxOrMacWorkstation -PropertyHashtable $LinuxOrMacRuleSet)
}

function Invoke-WindowsRuleSet 
{
    [cmdletbinding()]
    param ($CurrentState = $script:CurrentState)


    $Rules = @{
        LocalAccountLoginEnabled  = {}
        DomainAccountLoginEnabled = {}
        OnlySecureTrafficEnabled  = {}
        PlaintextTrafficAvailable = {}
        SecureTrafficAvailable    = {}
    }
    $WindowsRuleSet = @{}
    
    Write-Verbose "Validating Negotiate Auth for the WinRM Service is true:"
    Write-Verbose "`t$($CurrentState.Service.Auth.Negotiate.Path) is: $($CurrentState.Service.Auth.Negotiate.CurrentValue)"
    $WindowsRuleSet.NegotiateAuthEnabled = $CurrentState.Service.Auth.Negotiate.CurrentValue
    
    Write-Verbose "Validating Kerberos Auth for the WinRM Service is true:"
    Write-Verbose "`t$($CurrentState.Service.Auth.Kerberos.Path) is: $($CurrentState.Service.Auth.Kerberos.CurrentValue)"
    $WindowsRuleSet.KerberosAuthEnabled = $CurrentState.Service.Auth.Kerberos.CurrentValue


    return (New-CustomObject -TypeName Chef.WinRM.TestResult.WindowsWorkstation -PropertyHashtable $WindowsRuleSet)
}

function Invoke-WinRMRuleSet 
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
        {('LinuxOrMac', 'All') -contains $_ } { $Result.LinuxOrMacRuleSet = Invoke-LinuxOrMacRuleSet }
        {('Windows', 'All') -contains $_ } { $Result.WindowsRuleSet = Invoke-WindowsRuleSet }
        default {}
    }
    return (New-CustomObject -TypeName Chef.WinRM.TestResult -PropertyHashtable $Result)
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

function Get-WinRMListener
{
    New-CustomObject -TypeName Chef.WinRM.Listener -PropertyHashtable @{
        HTTP = Get-WinRMHttpListener
        HTTPS = Get-WinRMHttpsListener
    }
}

function Get-WinRMHttpListener 
{
    $CustomObjectProperties = @{
        TypeName = 'Chef.WinRM.Listener.Http'
        PropertyHashtable = @{
            CurrentValue = ([bool](dir $WinRMSettings.Listener.ProviderPath -Recurse | 
                where {$_.value -like 'HTTP'}))
        } 
    }
    New-CustomObject @CustomObjectProperties 
}

function Get-WinRMHttpsListener
{
    $CustomObjectProperties = @{
        TypeName = 'Chef.WinRM.Listener.Https'
        PropertyHashtable = @{
            CurrentValue = ([bool](dir $WinRMSettings.Listener.ProviderPath -Recurse | 
                where {$_.value -like 'HTTPS'}))
        }
    }
    New-CustomObject @CustomObjectProperties 
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
            Listener =  Get-WinRMListener
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

