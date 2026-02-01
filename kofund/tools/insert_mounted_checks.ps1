# Inserts `if (!mounted) return;` after awaits when a nearby line uses context/Navigator/ScaffoldMessenger
Get-ChildItem -Path . -Recurse -Filter *.dart | ForEach-Object {
    $path = $_.FullName
    $hasWarning = Select-String -Path $path -Pattern 'use_build_context_synchronously' -Quiet
    $isState = Select-String -Path $path -Pattern 'extends State' -Quiet
    if ($hasWarning -and $isState) {
        $lines = Get-Content $path -Raw -Encoding UTF8 -ErrorAction Stop -Split "\r?\n"
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
