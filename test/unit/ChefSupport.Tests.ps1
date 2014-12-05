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
        Listener = @{
            HTTP = New-Object PSObject -Property @{ CurrentValue = $true }
            HTTPS = New-Object PSObject -Property @{ CurrentValue = $false }
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
        context 'when AllowUnencrypted is enabled and Basic Auth is enabled.' {     
            $CurrentState = Get-CurrentState               
            $CurrentState.Service.AllowUnencrypted.CurrentValue = $true
            $CurrentState.Service.Auth.Basic.CurrentValue = $true
            

            it 'should have a report showing local account login is enabled' {
                (Invoke-LinuxOrMacRuleSet -CurrentState $CurrentState).LocalAccountLoginEnabled | 
                    should be $true
            }
        }
        context 'when AllowUnencrypted is disabled and Basic Auth is enabled and Negotiate Auth is disabled.' {     
            $CurrentState = Get-CurrentState               
            $CurrentState.Service.AllowUnencrypted.CurrentValue = $false
            $CurrentState.Service.Auth.Negotiate.CurrentValue = $false
            $CurrentState.Service.Auth.Basic.CurrentValue = $true            

            it 'should have a report showing local account login is disabled' {
                (Invoke-LinuxOrMacRuleSet -CurrentState $CurrentState).LocalAccountLoginEnabled | 
                    should be $false
            }
        }
        context 'when SSL and Negotiate Auth are enabled and Allow Unencrypted is not enabled' {
            $CurrentState = Get-CurrentState
            $CurrentState.Service.Auth.Basic.CurrentValue = $true
            $CurrentState.Service.Auth.Negotiate.CurrentValue = $true
            $CurrentState.Service.AllowUnencrypted.CurrentValue = $false
            $CurrentState.Listener.HTTPS.CurrentValue = $true

            it 'should have a report showing local account login is enabled' {
                (Invoke-LinuxOrMacRuleSet -CurrentState $CurrentState).LocalAccountLoginEnabled | 
                    should be $true
            }
            it 'should have a report showing domain account login is enabled' {
                (Invoke-LinuxOrMacRuleSet -CurrentState $CurrentState).DomainAccountLoginEnabled | 
                    should be $true
            }
        }
        context 'when LocalLogin is enabled and HTTPS is not available' {
            $CurrentState = Get-CurrentState               
            $CurrentState.Service.AllowUnencrypted.CurrentValue = $true
            $CurrentState.Service.Auth.Basic.CurrentValue = $true
            $CurrentState.Listener.HTTP.CurrentValue = $true 
            $CurrentState.Listener.HTTPS.CurrentValue = $false

            it 'should have a report showing Secure Traffic is not available' {
                (Invoke-LinuxOrMacRuleSet -CurrentState $CurrentState).SecureTrafficAvailable | 
                    should be $false
            }
            it 'should have a report showing Plaintext Traffic is available' {
                (Invoke-LinuxOrMacRuleSet -CurrentState $CurrentState).PlaintextTrafficAvailable | 
                    should be $true
            }
        }
        context 'when LocalLogin is enabled and HTTP and HTTPS are available' {
            $CurrentState = Get-CurrentState               
            $CurrentState.Service.AllowUnencrypted.CurrentValue = $true
            $CurrentState.Service.Auth.Basic.CurrentValue = $true
            $CurrentState.Listener.HTTP.CurrentValue = $true 
            $CurrentState.Listener.HTTPS.CurrentValue = $true

            it 'should have a report showing Secure Traffic is available' {
                (Invoke-LinuxOrMacRuleSet -CurrentState $CurrentState).SecureTrafficAvailable | 
                    should be $true
            }
            it 'should have a report showing Plaintext Traffic is available' {
                (Invoke-LinuxOrMacRuleSet -CurrentState $CurrentState).PlaintextTrafficAvailable | 
                    should be $true
            }
        }
    }    
    
    Describe 'how Invoke-WindowsRuleSet responds' {
        context 'when AllowUnencrypted is enabled and Basic Auth is enabled.' {     
            $CurrentState = Get-CurrentState               
            $CurrentState.Service.AllowUnencrypted.CurrentValue = $true
            $CurrentState.Service.Auth.Basic.CurrentValue = $true
           
            it 'should have a report showing local account login is enabled' {
                (Invoke-WindowsRuleSet -CurrentState $CurrentState).LocalAccountLoginEnabled | 
                    should be $true
            }
        }
        context 'when AllowUnencrypted is disabled and Basic Auth is enabled and Negotiate Auth is disabled.' {     
            $CurrentState = Get-CurrentState               
            $CurrentState.Service.AllowUnencrypted.CurrentValue = $false
            $CurrentState.Service.Auth.Negotiate.CurrentValue = $false
            $CurrentState.Service.Auth.Basic.CurrentValue = $true            

            it 'should have a report showing local account login is disabled' {
                (Invoke-WindowsRuleSet -CurrentState $CurrentState).LocalAccountLoginEnabled | 
                    should be $false
            }
        }
        context 'when Negotiate Auth is enabled and Allow Unencrypted is not enabled' {
            $CurrentState = Get-CurrentState
            $CurrentState.Service.Auth.Basic.CurrentValue = $true
            $CurrentState.Service.Auth.Negotiate.CurrentValue = $true
            $CurrentState.Service.AllowUnencrypted.CurrentValue = $false
            $CurrentState.Listener.HTTPS.CurrentValue = $false

            it 'should have a report showing local account login is enabled' {
                (Invoke-WindowsRuleSet -CurrentState $CurrentState).LocalAccountLoginEnabled | 
                    should be $true
            }
            it 'should have a report showing domain account login is enabled' {
                (Invoke-WindowsRuleSet -CurrentState $CurrentState).DomainAccountLoginEnabled | 
                    should be $true
            }
        }
        context 'when LocalLogin is enabled and HTTPS is not available' {
            $CurrentState = Get-CurrentState               
            $CurrentState.Service.AllowUnencrypted.CurrentValue = $false
            $CurrentState.Service.Auth.Negotiate.CurrentValue = $true
            $CurrentState.Listener.HTTP.CurrentValue = $true 
            $CurrentState.Listener.HTTPS.CurrentValue = $false

            it 'should have a report showing Secure Traffic is not available' {
                (Invoke-WindowsRuleSet -CurrentState $CurrentState).SecureTrafficAvailable | 
                    should be $true
            }
            it 'should have a report showing Plaintext Traffic is available' {
                (Invoke-WindowsRuleSet -CurrentState $CurrentState).PlaintextTrafficAvailable | 
                    should be $false
            }
        }
        context 'when LocalLogin is enabled and HTTP and HTTPS are available' {
            $CurrentState = Get-CurrentState               
            $CurrentState.Service.Auth.Negotiate.CurrentValue = $true
            $CurrentState.Listener.HTTP.CurrentValue = $true 
            $CurrentState.Listener.HTTPS.CurrentValue = $true

            it 'should have a report showing Secure Traffic is available' {
                (Invoke-WindowsRuleSet -CurrentState $CurrentState).SecureTrafficAvailable | 
                    should be $true
            }
            it 'should have a report showing Plaintext Traffic is available' {
                (Invoke-WindowsRuleSet -CurrentState $CurrentState).PlaintextTrafficAvailable | 
                    should be $true
            }
        }
    }
    
}