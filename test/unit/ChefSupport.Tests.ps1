Import-Module ChefSupport -Force

function Get-CurrentState 
{ 
    New-Object PSObject -Property @{
        MaxBatchItems = new-object PSObject -Property @{
            MinimumValue = 20
            CurrentValue = 32000
            RecommendedValue = 32000
        }
        MaxEnvelopeSizekb = new-object PSObject -Property @{
            MinimumValue = 150
            CurrentValue = 500
            RecommendedValue = 500 
        }
        MaxProviderRequests = new-object PSObject -Property @{
            MinimumValue = 25
            CurrentValue = 4294967295
            RecommendedValue = 4294967295
        }
        MaxTimeoutms = new-object PSObject -Property @{
            MinimumValue = 60000
            CurrentValue = 1800000
            RecommendedValue = 1800000
        }
        Service = New-Object PSObject -Property @{                
            AllowUnencrypted = New-Object PSObject -Property @{ 
                Path = 'wsman:/localhost/service/allowunencrypted'
                CurrentValue = $true
                RecommendedValue = $true 
            }
            MaxConcurrentOperations = New-Object PSObject -Property @{
                Path = 'wsman:/localhost/service/MaxConcurrentOperations'
                MinimumValue = 100
                CurrentValue = 4294967295
                RecommendedValue = 4294967295 
            }
            MaxConcurrentOperationsPerUser = New-Object PSObject -Property @{
                Path = 'wsman:/localhost/service/MaxConcurrentOperationsPerUser'
                MinimumValue = 15
                CurrentValue = 1500
                RecommendedValue = 1500
            }
            MaxConnections = New-Object PSObject -Property @{
                Path = 'wsman:/localhost/service/MaxConnections'
                MinimumValue = 25
                CurrentValue = 300
                RecommendedValue = 300
            } 
            Auth = New-Object PSObject -Property @{
                Basic = New-Object PSObject -Property @{ 
                    Path = 'wsman:/localhost/service/auth/basic'
                    CurrentValue = $true 
                }                
                Kerberos = New-Object PSObject -Property @{ 
                    Path = 'wsman:/localhost/service/auth/Kerberos'
                    CurrentValue = $true 
                }
                Negotiate = New-Object PSObject -Property @{ 
                    Path = 'wsman:/localhost/service/auth/Negotiate'
                    CurrentValue = $true 
                }
                CredSSP =  New-Object PSObject -Property @{ 
                    Path = 'wsman:/localhost/service/auth/CredSSP'
                    CurrentValue = $true 
                }
                Certificate = New-Object PSObject -Property @{ 
                    Path = 'wsman:/localhost/service/auth/Certificate'
                    CurrentValue = $true 
                }
            }               
        }
    } 
}

InModuleScope ChefSupport {
    Describe 'how Get-WinRMServiceState responds' {        
        context 'when WinRM is Stopped' {
            mock Get-Service -ParameterFilter {$Name -like 'WinRM'} -MockWith {
                new-object PSObject -Property @{Status = 'Stopped'}
            }

            it 'should return false' {
                Get-WinRMServiceState | should be $false
            }
        }
        context 'when WinRM is running' {
            mock Get-Service -ParameterFilter {$Name -like 'WinRM'} -MockWith {
                new-object PSObject -Property @{Status = 'Running'}
            }
            
            it 'should return true' {
                Get-WinRMServiceState  | should be $true
            }            
        }        
    }

    Describe 'how Test-WinRMServiceState responds' {
        context 'when WinRM is not running' {
            mock Get-WinRMServiceState -MockWith {$false}

            it 'should return false' {
                Test-WinRMServiceState | should be $false
            }
        }

        mock Get-WinRMServiceState -MockWith {$true}
        context 'when WinRM is running and all other settings are valid' { 

            it 'should return true' {
                Test-WinRMServiceState | should be $true
            }
        }        
    }

    Describe 'how Test-WinRMBaseConfiguration responds' {         
        context 'when MaxTimeout is the recommended value' {            
            $CurrentState = Get-CurrentState       
            it 'should return true' {
                Test-WinRMBaseConfiguration | should be $true
            }
        }
        context 'when MaxTimeout is above the recommended value' {
            $CurrentState = Get-CurrentState   
            $CurrentState.MaxTimeoutms.CurrentValue = $CurrentState.MaxTimeoutms.RecommendedValue + 100
            it 'should return true' {
                Test-WinRMBaseConfiguration | should be $true
            }
        }
        context 'when MaxTimeout is above the minimum value but below the recommended value' {
            $CurrentState = Get-CurrentState   
            $CurrentState.MaxTimeoutms.CurrentValue = $CurrentState.MaxTimeoutms.MinimumValue + 100
            it 'should return true' {
                Test-WinRMBaseConfiguration | should be $true
            }
        }
        context 'when MaxTimeoutms is below the minimum value' {
            $CurrentState = Get-CurrentState   
            $CurrentState.MaxTimeoutms.CurrentValue = $CurrentState.MaxTimeoutms.MinimumValue - 100
            it 'should return false' {
                Test-WinRMBaseConfiguration | should be $false
            }
        }
    }

    Describe 'how Test-WinRMServiceConfiguration responds' {        
        Context 'when there is no minimum value' {
            $CurrentState = Get-CurrentState   
            it 'should return true' {
                Test-WinRMServiceConfiguration | should be $true
            }            
        }
        Context 'when MaxConnections is less than the minimum' {
            $CurrentState = Get-CurrentState   
            $CurrentState.Service.MaxConnections.CurrentValue = $CurrentState.Service.MaxConnections.MinimumValue - 10 
            it 'should return false' {
                Test-WinRMServiceConfiguration | should be $false
            }
        }
        Context 'when MaxConnections is less than recommended but more than the minimum' {
            $CurrentState = Get-CurrentState   
            $CurrentState.Service.MaxConnections.CurrentValue = $CurrentState.Service.MaxConnections.MinimumValue + 10
            it 'should return true' {
                Test-WinRMServiceConfiguration | should be $true
            }
        }
        Context 'when MaxConnections is more than the recommended' {
            $CurrentState = Get-CurrentState   
            $CurrentState.Service.MaxConnections.CurrentValue = $CurrentState.Service.MaxConnections.RecommendedValue + 10
            it 'should return true' {
                Test-WinRMServiceConfiguration | should be $true
            }
        }        
    }

    Describe 'how Test-WinRMServiceAuthConfiguration responds' {        
        context 'when there is no recommended or minimum value for Basic auth and it is true' {
            $CurrentState = Get-CurrentState   
            it 'should return true' {
                Test-WinRMServiceAuthConfiguration | should be $true
            }
        }
        context 'when there is no recommended or minimum value for Basic auth and it is false' {
            $CurrentState = Get-CurrentState   
            $CurrentState.Service.Auth.Basic.CurrentValue = $false            
            it 'should return true' {
                Test-WinRMServiceAuthConfiguration | should be $true
            }
        }
    }
    
    Describe 'how Invoke-LinuxOrMacRuleSet responds' {        
        context 'when AllowUnencrypted is set to false' {     
            $CurrentState = Get-CurrentState               
            $CurrentState.Service.AllowUnencrypted.CurrentValue = $false

            it 'should return false' {
                (Invoke-LinuxOrMacRuleSet -CurrentState $CurrentState).IsValid | 
                    should be $false
            }
            it 'should have a report showing AllowUnencrypted is false' {
                (Invoke-LinuxOrMacRuleSet -CurrentState $CurrentState).AllowUnencryptedEnabled | 
                    should be $false
            }
        }
        context 'when AllowUnencrypted is set to true' {
            $CurrentState = Get-CurrentState
            $CurrentState.Service.AllowUnencrypted.CurrentValue = $true

            it 'should return true' {
                (Invoke-LinuxOrMacRuleSet -CurrentState $CurrentState).IsValid | 
                    should be $true
            }
            it 'should have a report showing AllowUnencrypted is true' {
                (Invoke-LinuxOrMacRuleSet -CurrentState $CurrentState).AllowUnencryptedEnabled | 
                    should be $true
            }            
        }
        context 'when Basic Auth is disabled' {
            $CurrentState = Get-CurrentState
            $CurrentState.Service.Auth.Basic.CurrentValue = $false

            it 'should return false' {
                (Invoke-LinuxOrMacRuleSet -CurrentState $CurrentState).IsValid | 
                    should be $false
            }
            it 'should have a report showing Basic Auth is not enabled' {
                (Invoke-LinuxOrMacRuleSet -CurrentState $CurrentState).BasicAuthEnabled | 
                    should be $false
            }  
        }
        context 'when Basic Auth is disabled' {
            $CurrentState = Get-CurrentState
            $CurrentState.Service.Auth.Basic.CurrentValue = $true

            it 'should return true' {
                (Invoke-LinuxOrMacRuleSet -CurrentState $CurrentState).IsValid | 
                    should be $true
            }
            it 'should have a report showing Basic Auth is enabled' {
                (Invoke-LinuxOrMacRuleSet -CurrentState $CurrentState).BasicAuthEnabled | 
                    should be $true
            }  
        }
    }    

    Describe 'how Invoke-WindowsRuleSet responds' {
        context 'when Negotiate Auth is disabled' {
            $CurrentState = Get-CurrentState               
            $CurrentState.Service.Auth.Negotiate.CurrentValue = $false            
            it 'should have a report showing Negotiate Auth is disabled' {
                (Invoke-WindowsRuleSet -CurrentState $CurrentState).NegotiateAuthEnabled | 
                    should be $false
            }
        }
        context 'when Negotiate Auth is enabled' {     
            $CurrentState = Get-CurrentState               
            $CurrentState.Service.Auth.Negotiate.CurrentValue = $true                      
            it 'should have a report showing Negotiate Auth is enabled' {
                (Invoke-WindowsRuleSet -CurrentState $CurrentState).NegotiateAuthEnabled | 
                    should be $true
            }
        }
        context 'when Kerberos Auth is disabled' {
            $CurrentState = Get-CurrentState               
            $CurrentState.Service.Auth.Kerberos.CurrentValue = $false            
            it 'should have a report showing Kerberos Auth is disabled' {
                (Invoke-WindowsRuleSet -CurrentState $CurrentState).KerberosAuthEnabled | 
                    should be $false
            }
        }
        context 'when Kerberos Auth is enabled' {     
            $CurrentState = Get-CurrentState               
            $CurrentState.Service.Auth.Kerberos.CurrentValue = $true                      
            it 'should have a report showing Kerberos Auth is enabled' {
                (Invoke-WindowsRuleSet -CurrentState $CurrentState).KerberosAuthEnabled | 
                    should be $true
            }
        } 
        
    }
}