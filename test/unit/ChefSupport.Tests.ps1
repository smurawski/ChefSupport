Import-Module ChefSupport -Force
InModuleScope ChefSupport {
    Describe 'how Get-WinRMServiceState responds' {        
        context 'when WinRM is Stopped' {
            mock Get-Service -ParameterFilter {$Name -like 'WinRM'} -MockWith {
                new-object PSObject -Property @{Status = 'Stopped'}
            }

            it 'it should return false' {
                Get-WinRMServiceState | should be $false
            }
        }
        context 'when WinRM is running' {
            mock Get-Service -ParameterFilter {$Name -like 'WinRM'} -MockWith {
                new-object PSObject -Property @{Status = 'Running'}
            }
            
            it 'it should return true' {
                Get-WinRMServiceState  | should be $true
            }            
        }        
    }

    Describe 'how Test-WinRMServiceState responds' {
        context 'when WinRM is not running' {
            mock Get-WinRMServiceState -MockWith {$false}

            it 'it should return false' {
                Test-WinRMServiceState | should be $false
            }
        }

        mock Get-WinRMServiceState -MockWith {$true}
        context 'when WinRM is running and all other settings are valid' { 

            it 'it should return true' {
                Test-WinRMServiceState | should be $true
            }
        }        
    }

    Describe 'how Test-WinRMBaseConfiguration responds' {
        $CurrentState = new-object PSObject -Property @{
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
        }
        
        context 'when MaxTimeout is the recommended value' {            
            it 'it should return true' {
                Test-WinRMBaseConfiguration | should be $true
            }
        }
        context 'when MaxTimeout is above the recommended value' {
            $CurrentState.MaxTimeoutms.CurrentValue = $CurrentState.MaxTimeoutms.RecommendedValue + 100
            it 'it should return true' {
                Test-WinRMBaseConfiguration | should be $true
            }
        }
        context 'when MaxTimeout is above the minimum value but below the recommended value' {
            $CurrentState.MaxTimeoutms.CurrentValue = $CurrentState.MaxTimeoutms.MinimumValue + 100
            it 'it should return true' {
                Test-WinRMBaseConfiguration | should be $true
            }
        }
        context 'when MaxTimeoutms is below the minimum value' {
            $CurrentState.MaxTimeoutms.CurrentValue = $CurrentState.MaxTimeoutms.MinimumValue - 100
            it 'it should return false' {
                Test-WinRMBaseConfiguration | should be $false
            }
        }
    }

    Describe 'how Test-WinRMServiceConfiguration responds' {
        $CurrentState = New-Object PSObject -Property @{
            Service = New-Object PSObject -Property @{                
                AllowUnencrypted = New-Object PSObject -Property @{ 
                    CurrentValue = $true
                    RecommendedValue = $true 
                }
                MaxConcurrentOperations = New-Object PSObject -Property @{
                    MinimumValue = 100
                    CurrentValue = 4294967295
                    RecommendedValue = 4294967295 
                }
                MaxConcurrentOperationsPerUser = New-Object PSObject -Property @{
                    MinimumValue = 15
                    CurrentValue = 1500
                    RecommendedValue = 1500
                }
                MaxConnections = New-Object PSObject -Property @{
                    MinimumValue = 25
                    CurrentValue = 300
                    RecommendedValue = 300
                }                
            }
        }

        Context 'when there is no minimum value' {
            it 'should return true' {
                Test-WinRMServiceConfiguration | should be $true
            }            
        }
        Context 'when MaxConnections is less than the minimum' {
            $CurrentState.Service.MaxConnections.CurrentValue = $CurrentState.Service.MaxConnections.MinimumValue - 10 
            it 'it should return false' {
                Test-WinRMServiceConfiguration | should be $false
            }
        }
        Context 'when MaxConnections is less than recommended but more than the minimum' {
            $CurrentState.Service.MaxConnections.CurrentValue = $CurrentState.Service.MaxConnections.MinimumValue + 10
            it 'it should return true' {
                Test-WinRMServiceConfiguration | should be $true
            }
        }
        Context 'when MaxConnections is more than the recommended' {
            $CurrentState.Service.MaxConnections.CurrentValue = $CurrentState.Service.MaxConnections.RecommendedValue + 10
            it 'it should return true' {
                Test-WinRMServiceConfiguration | should be $true
            }
        }
        
    }

    Describe 'how Test-WinRMServiceAuthConfiguration responds' {
        $CurrentState = New-Object PSObject -Property @{
            Service = New-Object PSObject -Property @{
                Auth = New-Object PSObject -Property @{
                    Basic = New-Object PSObject -Property @{ CurrentValue = $true }                
                    Kerberos = New-Object PSObject -Property @{ CurrentValue = $true }
                    Negotiate = New-Object PSObject -Property @{ CurrentValue = $true }
                    CredSSP =  New-Object PSObject -Property @{ CurrentValue = $true }
                    Certificate = New-Object PSObject -Property @{ CurrentValue = $true }
                }
            }
        }

        context 'when there is no recommended or minimum value for Basic auth and it is true' {
            it 'it should return true' {
                Test-WinRMServiceAuthConfiguration | should be $true
            }
        }

        context 'when there is no recommended or minimum value for Basic auth and it is false' {
            $CurrentState.Service.Auth.Basic.CurrentValue = $false            
            it 'it should return true' {
                Test-WinRMServiceAuthConfiguration | should be $true
            }
        }
    }    
}