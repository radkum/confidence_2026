
# ----------------------------------------------------------------------------------
#
# Copyright Microsoft Corporation
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------------------------------------------------------------

<#
.Synopsis
Creates key credentials or password credentials for an service principal.
.Description
Creates key credentials or password credentials for an service principal.
.Link
https://learn.microsoft.com/powershell/module/az.resources/new-azadspcredential
#>

function New-AzADSpCredential {
    [OutputType([Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.IMicrosoftGraphKeyCredential], [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.IMicrosoftGraphPasswordCredential])]
    [CmdletBinding(DefaultParameterSetName='SpObjectIdWithPasswordParameterSet', PositionalBinding=$false, SupportsShouldProcess, ConfirmImpact='Medium')]
    [Alias("New-AzADServicePrincipalCredential")]
    param(
        [Parameter(ParameterSetName='SpObjectIdWithPasswordParameterSet', Mandatory, HelpMessage = "The object Id of application.")]
        [Parameter(ParameterSetName='SpObjectIdWithCertValueParameterSet', Mandatory, HelpMessage = "The object Id of application.")]
        [Parameter(ParameterSetName='SpObjectIdWithKeyCredentialParameterSet', Mandatory, HelpMessage = "The object Id of application.")]
        [Parameter(ParameterSetName='SpObjectIdWithPasswordCredentialParameterSet', Mandatory, HelpMessage = "The object Id of application.")]
        [Alias('Id', 'ServicePrincipalObjectId')]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [System.String]
        ${ObjectId},

        [Parameter(ParameterSetName='SPNWithCertValueParameterSet', Mandatory, HelpMessage = "The service principal name.")]
        [Parameter(ParameterSetName='SPNWithPasswordParameterSet', Mandatory, HelpMessage = "The service principal name.")]
        [Parameter(ParameterSetName='SPNWithKeyCredentialParameterSet', Mandatory, HelpMessage = "The service principal name.")]
        [Parameter(ParameterSetName='SPNWithPasswordCredentialParameterSet', Mandatory, HelpMessage = "The service principal name.")]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [System.String]
        [Alias('SPN')]
        ${ServicePrincipalName},

        [Parameter(ParameterSetName='ServicePrincipalObjectWithCertValueParameterSet', Mandatory, ValueFromPipeline, HelpMessage = "The service principal object, could be used as pipeline input.")]
        [Parameter(ParameterSetName='ServicePrincipalObjectWithPasswordParameterSet', Mandatory, ValueFromPipeline, HelpMessage = "The service principal object, could be used as pipeline input.")]
        [Parameter(ParameterSetName='ServicePrincipalObjectWithKeyCredentialParameterSet', Mandatory, ValueFromPipeline, HelpMessage = "The service principal object, could be used as pipeline input.")]
        [Parameter(ParameterSetName='ServicePrincipalObjectWithPasswordCredentialParameterSet', Mandatory, ValueFromPipeline, HelpMessage = "The service principal object, could be used as pipeline input.")]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.IMicrosoftGraphServicePrincipal]
        ${ServicePrincipalObject},

        [Parameter(ParameterSetName='SpObjectIdWithCertValueParameterSet', Mandatory, HelpMessage = "The value of the 'asymmetric' credential type. It represents the base 64 encoded certificate.")]
        [Parameter(ParameterSetName='SPNWithCertValueParameterSet', Mandatory, HelpMessage = "The value of the 'asymmetric' credential type. It represents the base 64 encoded certificate.")]
        [Parameter(ParameterSetName='ServicePrincipalObjectWithCertValueParameterSet', Mandatory, HelpMessage = "The value of the 'asymmetric' credential type. It represents the base 64 encoded certificate.")]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [System.String]
        ${CertValue},

        [Parameter(ParameterSetName='SpObjectIdWithKeyCredentialParameterSet', Mandatory, HelpMessage = "key credentials associated with the service principal.")]
        [Parameter(ParameterSetName='SPNWithKeyCredentialParameterSet', Mandatory, HelpMessage = "key credentials associated with the service principal.")]
        [Parameter(ParameterSetName='ServicePrincipalObjectWithKeyCredentialParameterSet', Mandatory, HelpMessage = "key credentials associated with the service principal.")]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphKeyCredential[]]
        ${KeyCredentials},

        [Parameter(ParameterSetName='SpObjectIdWithPasswordCredentialParameterSet', Mandatory, HelpMessage = "Password credentials associated with the service principal.")]
        [Parameter(ParameterSetName='SPNWithPasswordCredentialParameterSet', Mandatory, HelpMessage = "Password credentials associated with the service principal.")]
        [Parameter(ParameterSetName='ServicePrincipalObjectWithPasswordCredentialParameterSet', Mandatory, HelpMessage = "Password credentials associated with the service principal.")]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphPasswordCredential[]]
        ${PasswordCredentials},

        [Parameter(ParameterSetName='SpObjectIdWithCertValueParameterSet', HelpMessage = "The effective start date of the credential usage. The default start date value is today. For an 'asymmetric' type credential, this must be set to on or after the date that the X509 certificate is valid from.")]
        [Parameter(ParameterSetName='SPNWithCertValueParameterSet', HelpMessage = "The effective start date of the credential usage. The default start date value is today. For an 'asymmetric' type credential, this must be set to on or after the date that the X509 certificate is valid from.")]
        [Parameter(ParameterSetName='ServicePrincipalObjectWithCertValueParameterSet', HelpMessage = "The effective start date of the credential usage. The default start date value is today. For an 'asymmetric' type credential, this must be set to on or after the date that the X509 certificate is valid from.")]
        [Parameter(ParameterSetName='SpObjectIdWithPasswordParameterSet', HelpMessage = "The effective start date of the credential usage. The default start date value is today. For an 'asymmetric' type credential, this must be set to on or after the date that the X509 certificate is valid from.")]
        [Parameter(ParameterSetName='SPNWithPasswordParameterSet', HelpMessage = "The effective start date of the credential usage. The default start date value is today. For an 'asymmetric' type credential, this must be set to on or after the date that the X509 certificate is valid from.")]
        [Parameter(ParameterSetName='ServicePrincipalObjectWithPasswordParameterSet', HelpMessage = "The effective start date of the credential usage. The default start date value is today. For an 'asymmetric' type credential, this must be set to on or after the date that the X509 certificate is valid from.")]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [System.DateTime]
        ${StartDate},

        [Parameter(ParameterSetName='SpObjectIdWithCertValueParameterSet', HelpMessage = "The effective end date of the credential usage. The default end date value is one year from today. For an 'asymmetric' type credential, this must be set to on or before the date that the X509 certificate is valid.")]
        [Parameter(ParameterSetName='SPNWithCertValueParameterSet', HelpMessage = "The effective end date of the credential usage. The default end date value is one year from today. For an 'asymmetric' type credential, this must be set to on or before the date that the X509 certificate is valid.")]
        [Parameter(ParameterSetName='ServicePrincipalObjectWithCertValueParameterSet', HelpMessage = "The effective end date of the credential usage. The default end date value is one year from today. For an 'asymmetric' type credential, this must be set to on or before the date that the X509 certificate is valid.")]
        [Parameter(ParameterSetName='SpObjectIdWithPasswordParameterSet', HelpMessage = "The effective end date of the credential usage. The default end date value is one year from today. For an 'asymmetric' type credential, this must be set to on or before the date that the X509 certificate is valid.")]
        [Parameter(ParameterSetName='SPNWithPasswordParameterSet', HelpMessage = "The effective end date of the credential usage. The default end date value is one year from today. For an 'asymmetric' type credential, this must be set to on or before the date that the X509 certificate is valid.")]
        [Parameter(ParameterSetName='ServicePrincipalObjectWithPasswordParameterSet', HelpMessage = "The effective end date of the credential usage. The default end date value is one year from today. For an 'asymmetric' type credential, this must be set to on or before the date that the X509 certificate is valid.")]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [System.DateTime]
        ${EndDate},

        [Parameter()]
        [Alias("AzContext", "AzureRmContext", "AzureCredential")]
        [ValidateNotNull()]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Azure')]
        [System.Management.Automation.PSObject]
        # The credentials, account, tenant, and subscription used for communication with Azure.
        ${DefaultProfile},
    
        [Parameter(DontShow)]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Runtime')]
        [System.Management.Automation.SwitchParameter]
        # Wait for .NET debugger to attach
        ${Break},
    
        [Parameter(DontShow)]
        [ValidateNotNull()]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Runtime')]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Runtime.SendAsyncStep[]]
        # SendAsync Pipeline Steps to be appended to the front of the pipeline
        ${HttpPipelineAppend},
    
        [Parameter(DontShow)]
        [ValidateNotNull()]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Runtime')]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Runtime.SendAsyncStep[]]
        # SendAsync Pipeline Steps to be prepended to the front of the pipeline
        ${HttpPipelinePrepend},
    
        [Parameter(DontShow)]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Runtime')]
        [System.Uri]
        # The URI for the proxy server to use
        ${Proxy},
    
        [Parameter(DontShow)]
        [ValidateNotNull()]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Runtime')]
        [System.Management.Automation.PSCredential]
        # Credentials for a proxy server to use for the remote call
        ${ProxyCredential},
    
        [Parameter(DontShow)]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Runtime')]
        [System.Management.Automation.SwitchParameter]
        # Use the default credentials for the proxy
        ${ProxyUseDefaultCredentials}
      )
    
    process {
        if (!$PSBoundParameters['PasswordCredentials'] -and !$PSBoundParameters['KeyCredentials']) {
            if ($PSBoundParameters['CertValue']) {
                $credential = New-Object -TypeName "Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphKeyCredential" `
                                         -Property @{'Key'=([System.Convert]::FromBase64String($PSBoundParameters['CertValue']));
                                                     'Usage'='Verify'; 
                                                     'Type'='AsymmetricX509Cert'}
            } else {
                $credential = New-Object -TypeName "Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphPasswordCredential"
            }
            if ($PSBoundParameters['StartDate']) {
                $credential.StartDateTime = $PSBoundParameters['StartDate']
                $null = $PSBoundParameters.Remove('StartDate')
            }
            if ($PSBoundParameters['EndDate']) {
                $credential.EndDateTime = $PSBoundParameters['EndDate']
                $null = $PSBoundParameters.Remove('EndDate')

            }
            $credential.KeyId = (New-Guid).ToString()
            if ($PSBoundParameters['CertValue']) {
                $kc = $credential
                $null = $PSBoundParameters.Remove('CertValue')
            } else {
                $pc = $credential
            }
        } elseif ($PSBoundParameters['PasswordCredentials']) {
            $pc = $PSBoundParameters['PasswordCredentials']
            $null = $PSBoundParameters.Remove('PasswordCredentials')
        } else {
            $kc = $PSBoundParameters['KeyCredentials']
            $null = $PSBoundParameters.Remove('PasswordCredentials')
        }
        
        $param = @{}
        switch ($PSCmdlet.ParameterSetName) {
            {$_ -in 'SpObjectIdWithPasswordParameterSet', 'SpObjectIdWithKeyCredentialParameterSet', 'SpObjectIdWithPasswordCredentialParameterSet', 'SpObjectIdWithCertValueParameterSet'} {
                $id = $PSBoundParameters['ObjectId']
                if ($kc) {
                    $sp = Get-AzADServicePrincipal -ObjectId $id
                }
                $null = $PSBoundParameters.Remove('ObjectId')
                break
            }
            {$_ -in 'SPNWithPasswordParameterSet', 'SPNWithKeyCredentialParameterSet', 'SPNWithPasswordCredentialParameterSet', 'SPNWithCertValueParameterSet'} {
                $param['ServicePrincipalName'] = $PSBoundParameters['ServicePrincipalName']
                $sp = Get-AzADServicePrincipal @param
                if($sp) {
                    $id = $sp.Id
                    $null = $PSBoundParameters.Remove('ServicePrincipalName')
                } else {
                    Write-Error "service principal with name '$($PSBoundParameters['ServicePrincipalName'])' does not exist."
                    return
                }
                break
            }
            {$_ -in 'ServicePrincipalObjectWithPasswordParameterSet', 'ServicePrincipalObjectWithKeyCredentialParameterSet', 'ServicePrincipalObjectWithPasswordCredentialParameterSet', 'ServicePrincipalObjectWithCertValueParameterSet'} {
                $id = $PSBoundParameters['ServicePrincipalObject'].Id
                if ($kc) {
                    $sp = Get-AzADServicePrincipal -ObjectId $id
                }
                $null = $PSBoundParameters.Remove('ServicePrincipalObject')
                break
            }
            default {
                break
            }
        } 
        if ($pc) {
            $PSBoundParameters['ServicePrincipalId'] = $id
            foreach ($credential in $pc) {
                $PSBoundParameters['PasswordCredential'] = $credential
                Az.MSGraph.internal\Add-AzADServicePrincipalPassword @PSBoundParameters
            }
            $null = $PSBoundParameters.Remove('ServicePrincipalId')
            if ($PSBoundParameters['PasswordCredential']) {
                $null = $PSBoundParameters.Remove('PasswordCredential')
            }
        }
        if ($kc) {
            [System.Array]$kcList = $sp.KeyCredentials
            $PSBoundParameters['Id'] = $id
            foreach ($k in $kc) {
                $kcList += $k
            }
            $PSBoundParameters['KeyCredentials'] = $kcList
            Az.MSGraph.internal\Update-AzADServicePrincipal @PSBoundParameters
        }  
    }
}
# SIG # Begin signature block
# MIIoUgYJKoZIhvcNAQcCoIIoQzCCKD8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA1x5KffLxf8WCR
# F3osBK+seGDFfRMiYPZ1l7DrCP4YkqCCDYUwggYDMIID66ADAgECAhMzAAAEhJji
# EuB4ozFdAAAAAASEMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjUwNjE5MTgyMTM1WhcNMjYwNjE3MTgyMTM1WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDtekqMKDnzfsyc1T1QpHfFtr+rkir8ldzLPKmMXbRDouVXAsvBfd6E82tPj4Yz
# aSluGDQoX3NpMKooKeVFjjNRq37yyT/h1QTLMB8dpmsZ/70UM+U/sYxvt1PWWxLj
# MNIXqzB8PjG6i7H2YFgk4YOhfGSekvnzW13dLAtfjD0wiwREPvCNlilRz7XoFde5
# KO01eFiWeteh48qUOqUaAkIznC4XB3sFd1LWUmupXHK05QfJSmnei9qZJBYTt8Zh
# ArGDh7nQn+Y1jOA3oBiCUJ4n1CMaWdDhrgdMuu026oWAbfC3prqkUn8LWp28H+2S
# LetNG5KQZZwvy3Zcn7+PQGl5AgMBAAGjggGCMIIBfjAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUBN/0b6Fh6nMdE4FAxYG9kWCpbYUw
# VAYDVR0RBE0wS6RJMEcxLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJh
# dGlvbnMgTGltaXRlZDEWMBQGA1UEBRMNMjMwMDEyKzUwNTM2MjAfBgNVHSMEGDAW
# gBRIbmTlUAXTgqoXNzcitW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIw
# MTEtMDctMDguY3JsMGEGCCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDEx
# XzIwMTEtMDctMDguY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIB
# AGLQps1XU4RTcoDIDLP6QG3NnRE3p/WSMp61Cs8Z+JUv3xJWGtBzYmCINmHVFv6i
# 8pYF/e79FNK6P1oKjduxqHSicBdg8Mj0k8kDFA/0eU26bPBRQUIaiWrhsDOrXWdL
# m7Zmu516oQoUWcINs4jBfjDEVV4bmgQYfe+4/MUJwQJ9h6mfE+kcCP4HlP4ChIQB
# UHoSymakcTBvZw+Qst7sbdt5KnQKkSEN01CzPG1awClCI6zLKf/vKIwnqHw/+Wvc
# Ar7gwKlWNmLwTNi807r9rWsXQep1Q8YMkIuGmZ0a1qCd3GuOkSRznz2/0ojeZVYh
# ZyohCQi1Bs+xfRkv/fy0HfV3mNyO22dFUvHzBZgqE5FbGjmUnrSr1x8lCrK+s4A+
# bOGp2IejOphWoZEPGOco/HEznZ5Lk6w6W+E2Jy3PHoFE0Y8TtkSE4/80Y2lBJhLj
# 27d8ueJ8IdQhSpL/WzTjjnuYH7Dx5o9pWdIGSaFNYuSqOYxrVW7N4AEQVRDZeqDc
# fqPG3O6r5SNsxXbd71DCIQURtUKss53ON+vrlV0rjiKBIdwvMNLQ9zK0jy77owDy
# XXoYkQxakN2uFIBO1UNAvCYXjs4rw3SRmBX9qiZ5ENxcn/pLMkiyb68QdwHUXz+1
# fI6ea3/jjpNPz6Dlc/RMcXIWeMMkhup/XEbwu73U+uz/MIIHejCCBWKgAwIBAgIK
# YQ6Q0gAAAAAAAzANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlm
# aWNhdGUgQXV0aG9yaXR5IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEw
# OTA5WjB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYD
# VQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+la
# UKq4BjgaBEm6f8MMHt03a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc
# 6Whe0t+bU7IKLMOv2akrrnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4D
# dato88tt8zpcoRb0RrrgOGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+
# lD3v++MrWhAfTVYoonpy4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nk
# kDstrjNYxbc+/jLTswM9sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6
# A4aN91/w0FK/jJSHvMAhdCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmd
# X4jiJV3TIUs+UsS1Vz8kA/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL
# 5zmhD+kjSbwYuER8ReTBw3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zd
# sGbiwZeBe+3W7UvnSSmnEyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3
# T8HhhUSJxAlMxdSlQy90lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS
# 4NaIjAsCAwEAAaOCAe0wggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRI
# bmTlUAXTgqoXNzcitW2oynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAL
# BgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBD
# uRQFTuHqp8cx0SOJNDBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3JsMF4GCCsGAQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3J0MIGfBgNVHSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEF
# BQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1h
# cnljcHMuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkA
# YwB5AF8AcwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn
# 8oalmOBUeRou09h0ZyKbC5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7
# v0epo/Np22O/IjWll11lhJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0b
# pdS1HXeUOeLpZMlEPXh6I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/
# KmtYSWMfCWluWpiW5IP0wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvy
# CInWH8MyGOLwxS3OW560STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBp
# mLJZiWhub6e3dMNABQamASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJi
# hsMdYzaXht/a8/jyFqGaJ+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYb
# BL7fQccOKO7eZS/sl/ahXJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbS
# oqKfenoi+kiVH6v7RyOA9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sL
# gOppO6/8MO0ETI7f33VtY5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtX
# cVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCGiMwghofAgEBMIGVMH4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01p
# Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAASEmOIS4HijMV0AAAAA
# BIQwDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIAE5
# XCX7GjdvXlvLq38ZRjDzE3u4LhsbVsVk/eGaLzuuMEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEAxbM4GOWlslSTXUe5OLjN28SVkj8XQg7HtC+l
# 9mmiJoal+XK08Nvak7yQWvPQvvpj4DTcdsunVq2yF+i211iDTM3Y7IfrntxK/LpQ
# wYgWBSzewBBBasLqMecNWTJjzpZmgBzzEf8NtLZ6LDFt8EGojqFO2IGQCI6TKUvx
# YX0DgHoC0LucjFukvBWK7MQiSZCA0mAII8PnXHcndGtvWAepaQLAB+5YK7OAFOxu
# 30EvU17yYwAirbPLa3HaMlIeHLFbQ0zdQEneYz8k+m3W6q/kiCcDtM/cvt6llfPL
# LwRrASNhBi+cQJ2znDcsQi1rSvJhYZ7ALwzlls2rMsJuCWmdgqGCF60wghepBgor
# BgEEAYI3AwMBMYIXmTCCF5UGCSqGSIb3DQEHAqCCF4YwgheCAgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFaBgsqhkiG9w0BCRABBKCCAUkEggFFMIIBQQIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCANrzu11LFRphV9tNKh+HfdS/TgqUzHtpg9
# A6JyibFHnAIGaZipr2qBGBMyMDI2MDIyNDA3MTgzOS44NTdaMASAAgH0oIHZpIHW
# MIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQL
# EyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsT
# Hm5TaGllbGQgVFNTIEVTTjo2RjFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEfswggcoMIIFEKADAgECAhMzAAACHAlV
# FdfDWQfRAAEAAAIcMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMB4XDTI1MDgxNDE4NDgzMVoXDTI2MTExMzE4NDgzMVowgdMxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jv
# c29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNoaWVs
# ZCBUU1MgRVNOOjZGMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# ow0xEAUaFIyyLIXeFzeI8IKyBON2u0Dr02ISE5p9G5CUXfnFu2S0E1gWCMvDWpop
# X6lRxjmgnqaL3BtnWlBVTo8xUNRZu23ie4YBMAJB7Ut6mnqnHVwvDJxGO4TD3Snr
# Cd+yg35B9QFejq3o4+OByvXjynaypZyukcQaLsKQvoxE8ElHH7zcOXEJWmU3rnXz
# aW/S4SH3OPhoUbTTcy6nUgKx5pRWiQ24UEPLYzcxGJjqjkz+GiCWGPFHDMdW86la
# WvmCslouQPsN2eBk8dxJcEZmW4l6p4TthoXcfexEA9YdYaMz10aMhZNpdsNaDtDQ
# UMDEC3k1D1My69MXSPlUmD9xFyDlkXiVa7BCEp3XcVtqTgzHGwr28JD6oE7zEPYe
# uZOiuCBXTZSo/wk3tbDlsESbIPV6inYqrzxiMYqlxfCdzC3Cimh9/NT/Lk9/aU+I
# yyc9b3OaT0dZ8wgLaVDCGELRMrqyImdFHv0MudctzW/kPsV3Ja9ufpKWujEiN3CW
# //X8hFa9j5ImNeQzcMit3MoSaoGwnbiZJX1IyibIphlqccXFk4oTTSOQBsAUw8U0
# gwOnM5UJD8mBUBd65Np6NBkx2cviJ4I34GyXFCWyy5Ft1QsBYyVfAG3KOhCfPHQf
# 8lQzJvLr57YW0bD/xVs4Ag4gTS6KZNyFEfX9jFdRlr0CAwEAAaOCAUkwggFFMB0G
# A1UdDgQWBBRa3mOCzB8u7zpvDh8MGKVYLCk7ZDAfBgNVHSMEGDAWgBSfpxVdAF5i
# XYP05dJlpxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENB
# JTIwMjAxMCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRp
# bWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1Ud
# JQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsF
# AAOCAgEAklb6w/deaid3BujQCtWFBe0n9pkyRy+yyWEg70iDwoJ5u0e0O+4GerNz
# dZb1zTPsHJ8EGMyo1K7ytL21+pmdFMTl19PC8OJ5Y2p+XKUQy2dD+hggRMmJgDQs
# gbOCxHYeO+jg4t+vg61wUrovzzLkH3z0PJXXvoNuBj9Lda9CiNMd60451Kube99A
# rSf6ZMj3t0p4rFbgSazDs+8TJ+8KA5GVaYjPHj9rlMuI3WjohEc9apnQ6hMjMck3
# jlHZIwluVYeUQE0qjmApfMtTAEzbMUdY8sLTunL1GkbDSeKn9O7llBGnNtyM1uM9
# Mdv1VyWh0z/IriQKIjntqqGyoF0HvDHOFZCyUDBPLflyiu7Y1zQ/sPounsb96aBf
# Qdq3h3LOn6t+m9EnNz/G6MzzWvpJk6YgTHTIqeQN/F/XpiPvbfek3nq/PYbL3au+
# kBfRUHiCFXSvt6lor0HC626vUmz9ZNPOxwEWLuccomxsy3JwWH79vsM/7ARqoG5h
# 6d6NahfaOuRP4XI9xtdH3Pa/NCLyQjxKXyLxzwQzjddkX2EpTJnlypuhPmEdea59
# Uz2E303LxyXSnKBvGsAnyWYAfnejr3YAiL9YrN2l2dn198RpA4DCm9QtZYiwC0q2
# fuUvui34PfPIUZByf7wHuuWu50hY9WLx1kOMI8xyo7AI6TaNrnIwggdxMIIFWaAD
# AgECAhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3Nv
# ZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0yMTA5MzAxODIy
# MjVaFw0zMDA5MzAxODMyMjVaMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA5OGmTOe0ciELeaLL1yR5
# vQ7VgtP97pwHB9KpbE51yMo1V/YBf2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64
# NmeFRiMMtY0Tz3cywBAY6GB9alKDRLemjkZrBxTzxXb1hlDcwUTIcVxRMTegCjhu
# je3XD9gmU3w5YQJ6xKr9cmmvHaus9ja+NSZk2pg7uhp7M62AW36MEBydUv626GIl
# 3GoPz130/o5Tz9bshVZN7928jaTjkY+yOSxRnOlwaQ3KNi1wjjHINSi947SHJMPg
# yY9+tVSP3PoFVZhtaDuaRr3tpK56KTesy+uDRedGbsoy1cCGMFxPLOJiss254o2I
# 5JasAUq7vnGpF1tnYN74kpEeHT39IM9zfUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2
# ci/bfV+AutuqfjbsNkz2K26oElHovwUDo9Fzpk03dJQcNIIP8BDyt0cY7afomXw/
# TNuvXsLz1dhzPUNOwTM5TI4CvEJoLhDqhFFG4tG9ahhaYQFzymeiXtcodgLiMxhy
# 16cg8ML6EgrXY28MyTZki1ugpoMhXV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y
# 1BzFa/ZcUlFdEtsluq9QBXpsxREdcu+N+VLEhReTwDwV2xo3xwgVGD94q0W29R6H
# XtqPnhZyacaue7e3PmriLq0CAwEAAaOCAd0wggHZMBIGCSsGAQQBgjcVAQQFAgMB
# AAEwIwYJKwYBBAGCNxUCBBYEFCqnUv5kxJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQW
# BBSfpxVdAF5iXYP05dJlpxtTNRnpcjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdMg30B
# ATBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3Bz
# L0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYB
# BAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMB
# Af8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBL
# oEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMv
# TWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggr
# BgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNS
# b29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwDQYJKoZIhvcNAQELBQADggIBAJ1Vffwq
# reEsH2cBMSRb4Z5yS/ypb+pcFLY+TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27
# DzHkwo/7bNGhlBgi7ulmZzpTTd2YurYeeNg2LpypglYAA7AFvonoaeC6Ce5732pv
# vinLbtg/SHUB2RjebYIM9W0jVOR4U3UkV7ndn/OOPcbzaN9l9qRWqveVtihVJ9Ak
# vUCgvxm2EhIRXT0n4ECWOKz3+SmJw7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWK
# NsIdw2FzLixre24/LAl4FOmRsqlb30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2
# kQH2zsZ0/fZMcm8Qq3UwxTSwethQ/gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+
# c23Kjgm9swFXSVRk2XPXfx5bRAGOWhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep
# 8beuyOiJXk+d0tBMdrVXVAmxaQFEfnyhYWxz/gq77EFmPWn9y8FBSX5+k77L+Dvk
# txW/tM4+pTFRhLy/AsGConsXHRWJjXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1Zyvg
# DbjmjJnW4SLq8CdCPSWU5nR0W2rRnj7tfqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/
# 2XBjU02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYIDVjCCAj4CAQEwggEBoYHZpIHW
# MIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQL
# EyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsT
# Hm5TaGllbGQgVFNTIEVTTjo2RjFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIaAxUAWmTiA01u5mxq
# /nVxiRJLMOskVGeggYMwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAx
# MDANBgkqhkiG9w0BAQsFAAIFAO1HxUcwIhgPMjAyNjAyMjQwNjM1NTFaGA8yMDI2
# MDIyNTA2MzU1MVowdDA6BgorBgEEAYRZCgQBMSwwKjAKAgUA7UfFRwIBADAHAgEA
# AgIVpzAHAgEAAgIS4jAKAgUA7UkWxwIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgor
# BgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBCwUA
# A4IBAQBlVEuEgksvnCRtVdtPp/lrQ6EQ85WvaY+aRm5Yj65d8k9bb6t7TzMQxxnh
# uDaB0/pssTytI0xCW38hLl5iUT3vUG30O6J7LxVBWz3YOLwGSQtAgNgEO+IoCg2u
# qKQCalZW6I7K55xPNlrv/qyxO3RIqYUOTJmlwVGyd3m+RTaoiKWwnrufsjZ8c4qY
# uLiTGTxPvwNrunTH6JSAHXeWYSwGeTtFM+a+pguPNnv/Vz9m5n2sVxo4JDlpeZnc
# mDbxgaJcCD4LSuny9UX2/B+8imwF2/FfKmLjo+TDECl6q3TdPiRY2DhRTxya9mU6
# p+jag0rWwgpgMnsIcBp/cJxb+4SHMYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAIcCVUV18NZB9EAAQAAAhwwDQYJYIZIAWUD
# BAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0B
# CQQxIgQgkx1eIEdVNU/da9Wqf18tOeF0vKS0XOKK/pHhQkhCYWcwgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCCgIGkmNhdo7+KE7dWhI+E2Ctx2RLWoYvvJodCI
# ciHHaDCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAC
# HAlVFdfDWQfRAAEAAAIcMCIEIM1hTa696i1Q4Z+nnEo7ckzmnyAEKxtCL6nfCoLn
# aQhiMA0GCSqGSIb3DQEBCwUABIICAJNPVAAx5vj9MZ4CcxRl98kA0qGnOFNosNV/
# bVN7LiKwC3YG4J9BQ1/xmrE9NhevEM6KpoOa/onFAObd69lcW2vrYdbPsydbXNLA
# BxLqRUGX6PEaCSX6cLdiQoG9h/Cucq9oqqUfiekcTjpipC18OJFnjJyyHcMvVFpz
# fCrsUKJQSOE/jvQnkEFSMeUbISJMZ2xKn5LKh6d4ymcl8p/nBAog8Vkfl36nt5ps
# /q19Vu4KalChyv2VLNabw4UWjazrj00Up9DW8mXgAteFTBqXz+Ug9cXlhMC4C8vn
# u8nxCLZ+7BIKw2oLyf5uiGhok1HuSNTLZkJRKBUNJBl/pL5u0TszjD5tOxOtraZt
# yC3mtUh2NIHzZmv2BqU4XbXh+LMvERt7dGm1FTLMdnNDvRvXXbP3ryOcBVPXVG0T
# q9JTqN0xNOFuNy/shMO/YfPcZjhgowanYXzTBnztytGHUfisntdFDkfi8yKTQ34P
# v/YUFx06YfiLbh/Dq4Vj5HFuXpe4peh2jww4Fa5oRaDH7QOPwnrzRD+g7WoNUUOY
# AwqedG2eDYX3Uwsyzmzg+Yu+PetQax5gTzQo9/cXrra/Hcbuuv/PoyYDvNNP+8H7
# StecXFXhYZKqO/gjxgHcPNw/tVFPDweYawJQUaHQmlYpvVFuv/nZR6/fab9j5iEx
# yUDQKyMZ
# SIG # End signature block
