# Scans all dart files under lib and inserts `if (!mounted) return;` after await statements when a nearby line references context/Navigator/ScaffoldMessenger/showDialog/SnackBar.
Get-ChildItem -Path lib -Recurse -Filter *.dart | ForEach-Object {
    $path = $_.FullName
    $isState = Select-String -Path $path -Pattern 'extends State' -Quiet
    if ($isState) {
        $lines = Get-Content $path -Encoding UTF8 -ErrorAction Stop
        $out = New-Object System.Collections.Generic.List[System.String]
        $changed = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $out.Add($lines[$i])
            if ($lines[$i] -match '\bawait\b.*;') {
                $lookAheadEnd = [Math]::Min($lines.Count - 1, $i + 5)
                for ($j = $i + 1; $j -le $lookAheadEnd; $j++) {
                    if ($lines[$j] -match '\b(context\.|Navigator\.|ScaffoldMessenger|showDialog|SnackBar|Navigator\.of\()') {
                        $indent = ($lines[$i] -replace '(\S.*$)', '')
                        $checkLine = $indent + 'if (!mounted) return;'
                        if (($i + 1) -lt $lines.Count -and $lines[$i + 1].Trim() -eq $checkLine.Trim()) {
                            # already present
                        } else {
                            $out.Add($checkLine)
                            $changed = $true
                        }
                        break
                    }
                }
            }
        }
        if ($changed) {
            $out -join "`n" | Set-Content -Path $path -Encoding UTF8
            Write-Host "Patched: $path"
        }
    }
}
