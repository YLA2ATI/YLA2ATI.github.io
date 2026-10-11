@echo off
setlocal DisableDelayedExpansion
title PowerKuy Setup
set "GTPS_SELF=%~f0"
set "GTPS_MODE=%~1"
set "GTPS_RESULT="
set "GTPS_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "GTPS_PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%GTPS_PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$text=[IO.File]::ReadAllText($env:GTPS_SELF);$marker=[regex]::Match($text,'(?m)^# GTPS_POWERSHELL\r?$');if(-not $marker.Success){throw 'Installer payload is missing.'};& ([scriptblock]::Create($text.Substring($marker.Index+$marker.Length))) -Mode $env:GTPS_MODE"
set "GTPS_EXIT=%errorlevel%"
echo.
echo Press any key to close this window . . .
pause >nul
exit /b %GTPS_EXIT%
# GTPS_POWERSHELL
param([string]$Mode = 'auto')
$ErrorActionPreference = 'Stop'
$script:ServerIp = '45.150.149.37'
$script:Names = @('www.growtopia1.com', 'www.growtopia2.com')
$script:CaBytes = [Convert]::FromBase64String('MIIDhTCCAm2gAwIBAgIUf56zoAxJQqGa5H1tU4ljQnfFBgQwDQYJKoZIhvcNAQELBQAwSjELMAkGA1UEBhMCSUQxETAPBgNVBAoMCFBvd2VyS3V5MQ0wCwYDVQQLDARHVFBTMRkwFwYDVQQDDBBQb3dlckt1eSBSb290IENBMB4XDTI2MTAxMDE1NTY0MloXDTM2MTAwNzE1NTY0MlowSjELMAkGA1UEBhMCSUQxETAPBgNVBAoMCFBvd2VyS3V5MQ0wCwYDVQQLDARHVFBTMRkwFwYDVQQDDBBQb3dlckt1eSBSb290IENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsrH+phWLKhnVJgI65COY3yLWdmf5Mgjnw1LxKVWQQWFUAFvMB3qK3mM8k2p9Ul9Ixu5VCFDr91lPxclzYsvZKnGiS/n4wq4SIqhqQYLvDXYv969lt2zFpczTOjmDgXm1chIAQA0KxgNbXsa+7sS3MizrAfM7kU/w3mj/xOtHyJe58tN0OO3gCZzZR9w9R0Kz6Z8uv2jznz5hMvjdoGLjO4ZrEqEbHL4WgnBd1x04mrwwg5fxvQDN4x6nHGEJStQ6cvyL2Fr5JFrMSV5I+IgLSZjWHZ1BNM4lPOCH+AXsel4Jhg1S/UpdKzr1hggcULVaXkc7ceMIrDPS5exOkGV0pQIDAQABo2MwYTAdBgNVHQ4EFgQU5c94bOi42ckNVS5e2sCWT61RVgQwHwYDVR0jBBgwFoAU5c94bOi42ckNVS5e2sCWT61RVgQwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwDQYJKoZIhvcNAQELBQADggEBAIKCDWmW37b65BqmoSkIg6T58sY9G19Sv857fcot1KjrOCCJQBsfEmPWvX4cnDpd+ku3QIdvvttjSa5QM+XEdNU4kVhZAwMSSD6SGVyx5LNW6vNRGomlziw2I+rHHo7AGa8HPLyCGYeBhDFjZlcE83Tsmj8CTwsYs19WOJKMUqsbriH0oC3k0u2u367rn6NvJbwQlr8CfPXHuNfMfaB2eOyi+ForF7ZmceZ35tZLoGBqR/CRVHezxoa5UCKkHbXFRZ4etALTbCNm5VETzaUpmvIEjnhx9H7/PkOHawuukRX8HSsAvWYVWKldm5yox33moy968Wc4mlXp7kumpkdCPWM=')
$script:Ca = New-Object Security.Cryptography.X509Certificates.X509Certificate2(,$script:CaBytes)
$script:HostsPath = Join-Path ([Environment]::SystemDirectory) 'drivers\etc\hosts'
$script:StateFolder = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'PowerKuy-Link'
$script:StatePath = Join-Path $script:StateFolder 'installer-state.json'

function Resolve-GtpsMode {
    param([string]$Mode)
    # Always connect on a normal run. (An explicit 'remove' argument still works
    # for a manual disconnect, but a plain double-click never disconnects.)
    if ($Mode -eq 'remove') { return 'remove' }
    return 'install'
}

function Write-GtpsProgress {
    param([string]$Action, [int]$Percent, [string]$Status)
    if ($env:GTPS_RESULT) {
        # Progress is optional; a display problem must not interrupt installation.
        try {
            $json = @{finished=$false;action=$Action;percent=$Percent;status=$Status} | ConvertTo-Json
            Write-GtpsBytes $env:GTPS_RESULT ([Text.UTF8Encoding]::new($false).GetBytes($json))
        } catch { }
    } else {
        $activity = if ($Action -eq 'remove') { 'Disconnecting PowerKuy' } else { 'Connecting PowerKuy' }
        Write-Progress -Id 1 -Activity $activity -Status $Status -PercentComplete $Percent
    }
}

function Read-GtpsReport {
    param([string]$Path)
    $stream = $null
    $reader = $null
    try {
        $stream = [IO.File]::Open($Path, 'Open', 'Read', ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $reader = [IO.StreamReader]::new($stream)
        return ($reader.ReadToEnd() | ConvertFrom-Json)
    } catch { return $null }
    finally {
        if ($reader) { $reader.Dispose() }
        elseif ($stream) { $stream.Dispose() }
    }
}

function Show-GtpsMessages {
    param([string[]]$Messages, [int]$Code)
    Write-Progress -Id 1 -Activity 'PowerKuy Setup' -Completed
    Write-Host ''
    for ($index = 0; $index -lt $Messages.Count; $index++) {
        $color = if ($index -eq 0) { if ($Code -eq 0) { 'Green' } else { 'Red' } } else { 'Gray' }
        Write-Host ('  ' + $Messages[$index]) -ForegroundColor $color
    }
}

function Get-GtpsHostsText {
    param([string]$Text, [switch]$Remove)
    $newline = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $output = [Collections.Generic.List[string]]::new()
    foreach ($line in [regex]::Split($Text, '\r\n|\n|\r')) {
        $hash = $line.IndexOf('#')
        $body = if ($hash -ge 0) { $line.Substring(0, $hash) } else { $line }
        $comment = if ($hash -ge 0) { $line.Substring($hash) } else { '' }
        $parts = @($body.Trim() -split '\s+' | Where-Object { $_ })
        $address = $null
        if ($parts.Count -lt 2 -or -not [Net.IPAddress]::TryParse($parts[0], [ref]$address) -or
            ($Remove -and $address.ToString() -ne $script:ServerIp)) {
            $output.Add($line)
            continue
        }
        $aliases = @($parts | Select-Object -Skip 1)
        $kept = @($aliases | Where-Object { $script:Names -notcontains $_.TrimEnd('.') })
        if ($kept.Count -eq $aliases.Count) { $output.Add($line); continue }
        if ($kept.Count) {
            $changed = $parts[0] + "`t" + ($kept -join ' ')
            if ($comment) { $changed += "`t" + $comment }
            $output.Add($changed)
        } elseif ($comment) { $output.Add($comment) }
    }
    while ($output.Count -gt 0 -and $output[$output.Count - 1] -eq '') {
        $output.RemoveAt($output.Count - 1)
    }
    if (-not $Remove) {
        foreach ($name in $script:Names) { $output.Add($script:ServerIp + ' ' + $name) }
    }
    if ($output.Count -eq 0) { return '' }
    return ($output -join $newline) + $newline
}

function Read-GtpsHosts {
    $exists = [IO.File]::Exists($script:HostsPath)
    $bytes = [byte[]]@()
    if ($exists) { $bytes = [IO.File]::ReadAllBytes($script:HostsPath) }
    $encoding = [Text.UTF8Encoding]::new($false, $true)
    $skip = 0
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) {
        $encoding = [Text.UTF8Encoding]::new($true); $skip = 3
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 255 -and $bytes[1] -eq 254) {
        $encoding = [Text.Encoding]::Unicode; $skip = 2
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 254 -and $bytes[1] -eq 255) {
        $encoding = [Text.Encoding]::BigEndianUnicode; $skip = 2
    }
    try { $text = $encoding.GetString($bytes, $skip, $bytes.Length - $skip) }
    catch { $encoding = [Text.Encoding]::Default; $text = $encoding.GetString($bytes) }
    return @{Exists=$exists;Bytes=[byte[]]$bytes;Text=$text;Encoding=$encoding}
}

function Write-GtpsBytes {
    param([string]$Path, [byte[]]$Bytes)
    $temporary = Join-Path ([IO.Path]::GetDirectoryName($Path)) ('.gtps-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllBytes($temporary, $Bytes)
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temporary, $Path, [NullString]::Value) }
        else { [IO.File]::Move($temporary, $Path) }
    } finally {
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
}

function Write-GtpsHosts {
    param([string]$Text, $Original)
    $stream = [IO.MemoryStream]::new()
    try {
        $prefix = $Original.Encoding.GetPreamble()
        $bytes = $Original.Encoding.GetBytes($Text)
        $stream.Write($prefix, 0, $prefix.Length)
        $stream.Write($bytes, 0, $bytes.Length)
        Write-GtpsBytes $script:HostsPath $stream.ToArray()
    } finally { $stream.Dispose() }
}

function Restore-GtpsHosts {
    param($Original)
    if ($Original.Exists) { Write-GtpsBytes $script:HostsPath $Original.Bytes }
    elseif ([IO.File]::Exists($script:HostsPath)) { [IO.File]::Delete($script:HostsPath) }
}

function Test-GtpsRoot {
    $store = [Security.Cryptography.X509Certificates.X509Store]::new('Root', 'LocalMachine')
    try {
        $store.Open('ReadOnly')
        return $store.Certificates.Find('FindByThumbprint', $script:Ca.Thumbprint, $false).Count -gt 0
    } finally { $store.Close() }
}

function Set-GtpsRoot {
    param([bool]$Present)
    $store = [Security.Cryptography.X509Certificates.X509Store]::new('Root', 'LocalMachine')
    try {
        $store.Open('ReadWrite')
        if ($Present) { $store.Add($script:Ca) }
        else {
            foreach ($certificate in $store.Certificates.Find('FindByThumbprint', $script:Ca.Thumbprint, $false)) {
                $store.Remove($certificate)
            }
        }
    } finally { $store.Close() }
}

function Clear-GtpsDns {
    $ipconfig = Join-Path ([Environment]::SystemDirectory) 'ipconfig.exe'
    $null = & $ipconfig /flushdns 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Windows could not flush the DNS cache.' }
}

function Get-GtpsState {
    if (-not [IO.File]::Exists($script:StatePath)) { return $null }
    $state = [IO.File]::ReadAllText($script:StatePath) | ConvertFrom-Json
    if ($state.caThumbprint -ne $script:Ca.Thumbprint) { return $null }
    return $state
}

function Save-GtpsState {
    param([bool]$OwnsCa)
    $json = @{caThumbprint=$script:Ca.Thumbprint;caAddedByInstaller=$OwnsCa} | ConvertTo-Json
    Write-GtpsBytes $script:StatePath ([Text.UTF8Encoding]::new($false).GetBytes($json))
}

function Invoke-GtpsInstall {
    $original = Read-GtpsHosts
    $state = Get-GtpsState
    $rootExisted = Test-GtpsRoot
    $rootAdded = $false
    $hostsWritten = $false
    try {
        Write-GtpsProgress install 10 'Preparing your PowerKuy setup...'
        $null = [IO.Directory]::CreateDirectory($script:StateFolder)
        $backup = Join-Path $script:StateFolder 'hosts.before-powerkuy'
        if (-not [IO.File]::Exists($backup)) { [IO.File]::WriteAllBytes($backup, $original.Bytes) }
        Write-GtpsProgress install 30 'Installing the HTTPS certificate...'
        if (-not $rootExisted) { Set-GtpsRoot $true; $rootAdded = $true }
        Write-GtpsProgress install 55 'Adding the Growtopia hosts entries...'
        $updated = Get-GtpsHostsText $original.Text
        if ($updated -cne $original.Text) { Write-GtpsHosts $updated $original; $hostsWritten = $true }
        Write-GtpsProgress install 80 'Refreshing the Windows DNS cache...'
        Clear-GtpsDns
        Write-GtpsProgress install 95 'Finishing setup...'
        Save-GtpsState ($rootAdded -or ($state -and $state.caAddedByInstaller -eq $true))
    } catch {
        $failure = $_.Exception.Message
        try {
            if ($hostsWritten) { Restore-GtpsHosts $original; Clear-GtpsDns }
            if ($rootAdded) { Set-GtpsRoot $false }
        } catch { throw ($failure + ' Rollback also failed: ' + $_.Exception.Message) }
        throw ($failure + ' Changes from this attempt were rolled back.')
    }
    return @('PowerKuy connected successfully!',
             'Growtopia hosts entries and the HTTPS certificate are ready.',
             '',
             'Close and reopen Growtopia, then log out and log back in.',
             'You are all set - run this file any time to reconnect.')
}

function Invoke-GtpsRemove {
    $original = Read-GtpsHosts
    $state = Get-GtpsState
    $hostsWritten = $false
    $rootRemoved = $false
    try {
        Write-GtpsProgress remove 20 'Removing the PowerKuy hosts entries...'
        $updated = Get-GtpsHostsText $original.Text -Remove
        if ($updated -cne $original.Text) { Write-GtpsHosts $updated $original; $hostsWritten = $true }
        Write-GtpsProgress remove 50 'Refreshing the Windows DNS cache...'
        Clear-GtpsDns
        Write-GtpsProgress remove 75 'Removing the certificate added by this installer...'
        if ($state -and $state.caAddedByInstaller -eq $true -and (Test-GtpsRoot)) {
            Set-GtpsRoot $false; $rootRemoved = $true
        }
        Write-GtpsProgress remove 95 'Finishing...'
        if ($state -and [IO.File]::Exists($script:StatePath)) { [IO.File]::Delete($script:StatePath) }
    } catch {
        $failure = $_.Exception.Message
        try {
            if ($hostsWritten) { Restore-GtpsHosts $original; Clear-GtpsDns }
            if ($rootRemoved) { Set-GtpsRoot $true }
        } catch { throw ($failure + ' Rollback also failed: ' + $_.Exception.Message) }
        throw ($failure + ' Changes from this attempt were rolled back.')
    }
    return @('Disconnected from PowerKuy successfully!',
             'The PowerKuy hosts entries have been removed.',
             '',
             'Close and reopen Growtopia to apply the change.',
             'To connect to PowerKuy, run this same file again.')
}

function Invoke-GtpsMain {
    param([string]$Mode)
    if (-not $Mode) { $Mode = 'auto' }
    if ($Mode -notin @('auto', 'install', 'remove')) {
        Write-Host 'Usage: PowerKuy-Setup.bat (connect/disconnect automatically), or add install / remove'
        exit 2
    }
    try { $Mode = Resolve-GtpsMode $Mode }
    catch {
        Show-GtpsMessages @('Could not read the Windows hosts file: ' + $_.Exception.GetBaseException().Message) 1
        exit 1
    }
    if (-not $env:GTPS_RESULT) {
        Write-Host ''
        Write-Host '  POWERKUY SETUP' -ForegroundColor Cyan
        Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
        Write-Host '  Connect Growtopia to the PowerKuy GrowLuncher.'
        Write-Host '  Sets up the Windows hosts entries and HTTPS certificate.'
        Write-Host '  Run this file any time to connect.'
        Write-Host ''
        if ($Mode -eq 'remove') {
            Write-Host '  Action: DISCONNECT FROM POWERKUY' -ForegroundColor Yellow
        } else {
            Write-Host '  Action: CONNECT TO POWERKUY' -ForegroundColor Cyan
        }
    }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $admin = ([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $admin) {
        $resultPath = [IO.Path]::GetTempFileName()
        try {
            Write-Host '  Windows needs administrator access to update hosts.' -ForegroundColor DarkGray
            Write-Host '  Approve the Windows prompt to continue.' -ForegroundColor DarkGray
            Write-GtpsProgress $Mode 0 'Waiting for administrator access...'
            $self = "'" + $env:GTPS_SELF.Replace("'", "''") + "'"
            $result = "'" + $resultPath.Replace("'", "''") + "'"
            $bootstrap = '$env:GTPS_SELF=' + $self + ';$env:GTPS_RESULT=' + $result + ';' +
                '$text=[IO.File]::ReadAllText($env:GTPS_SELF);$marker=[regex]::Match($text,''(?m)^# GTPS_POWERSHELL\r?$'');' +
                '& ([scriptblock]::Create($text.Substring($marker.Index+$marker.Length))) -Mode ''' + $Mode + ''''
            $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($bootstrap))
            $shell = Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
            $process = Start-Process -FilePath $shell -Verb RunAs -WindowStyle Hidden -PassThru -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded)
            $lastStatus = ''
            while (-not $process.HasExited) {
                $report = Read-GtpsReport $resultPath
                if ($report -and -not $report.finished -and $report.status -ne $lastStatus) {
                    Write-GtpsProgress $Mode $report.percent $report.status
                    $lastStatus = $report.status
                }
                Start-Sleep -Milliseconds 100
                $process.Refresh()
            }
            $process.WaitForExit()
            $report = Read-GtpsReport $resultPath
            if (-not $report -or $report.finished -ne $true) { throw 'The elevated installer did not return a result.' }
            Show-GtpsMessages $report.messages $report.exitCode
            exit $process.ExitCode
        } catch {
            Show-GtpsMessages @('PowerKuy setup did not complete: ' + $_.Exception.GetBaseException().Message) 1
            exit 1
        } finally {
            if ([IO.File]::Exists($resultPath)) { [IO.File]::Delete($resultPath) }
        }
    }
    $code = 0
    try {
        if ($Mode -eq 'remove') { $messages = @(Invoke-GtpsRemove) }
        else { $messages = @(Invoke-GtpsInstall) }
    } catch { $code = 1; $messages = @('Setup failed: ' + $_.Exception.GetBaseException().Message) }
    if ($env:GTPS_RESULT) {
        $json = @{finished=$true;messages=$messages;exitCode=$code} | ConvertTo-Json
        Write-GtpsBytes $env:GTPS_RESULT ([Text.UTF8Encoding]::new($false).GetBytes($json))
    } else { Show-GtpsMessages $messages $code }
    exit $code
}

Invoke-GtpsMain -Mode $Mode
