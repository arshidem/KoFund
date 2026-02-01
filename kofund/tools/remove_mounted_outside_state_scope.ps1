Get-ChildItem lib -Recurse -Filter *.dart | ForEach-Object {
    $path = $_.FullName
    $lines = Get-Content $path -Encoding UTF8

    # Find State<T> class body ranges (startLineIndex, endLineIndex)
    $stateRanges = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'class\s+\w+\s+extends\s+State\s*<') {
            # find the line with the first '{' from here
            $openLine = $i
            while ($openLine -lt $lines.Count -and ($lines[$openLine] -notmatch '\{')) { $openLine++ }
            if ($openLine -ge $lines.Count) { continue }
            $depth = ([regex]::Matches($lines[$openLine], '\{').Count) - ([regex]::Matches($lines[$openLine], '\}').Count)
            $j = $openLine + 1
            while ($j -lt $lines.Count -and $depth -gt 0) {
                $depth += ([regex]::Matches($lines[$j], '\{').Count)
                $depth -= ([regex]::Matches($lines[$j], '\}').Count)
                $j++
            }
            $endLine = [Math]::Min($lines.Count - 1, $j - 1)
            $stateRanges += ,(@($openLine, $endLine))
            $i = $endLine
        }
    }

    if ($stateRanges.Count -eq 0) { continue }

    $newLines = New-Object System.Collections.Generic.List[System.String]
    $removed = $false
    for ($idx = 0; $idx -lt $lines.Count; $idx++) {
        $line = $lines[$idx]
        $isMountedLine = $line -match '^\s*if\s*\(!mounted\)\s*return;\s*$'
        if ($isMountedLine) {
            $insideState = $false
            foreach ($r in $stateRanges) {
                $s = $r[0]; $e = $r[1]
                if ($idx -ge $s -and $idx -le $e) { $insideState = $true; break }
            }
            if (-not $insideState) {
                $removed = $true
                continue
            }
        }
        $newLines.Add($line)
    }

    if ($removed) {
        $newLines -join "`n" | Set-Content -Path $path -Encoding UTF8
        Write-Host "Removed mounted checks outside State in: $path"
    }
}
