Get-ChildItem lib -Recurse -Filter *.dart | ForEach-Object {
    $path = $_.FullName
    $lines = Get-Content $path -Encoding UTF8
    $hasMounted = $lines | Where-Object { $_ -match 'if \(!mounted\) return;' }
    if ($hasMounted) {
        $isState = $lines -join "`n" -match 'extends\s+State\s*<'
        if (-not $isState) {
            $new = $lines | Where-Object { -not ($_ -match '^\s*if\s*\(!mounted\)\s*return;\s*$') }
            if ($new.Count -ne $lines.Count) {
                $new | Set-Content $path -Encoding UTF8
                Write-Host "Removed mounted check from non-State file: $path"
            }
        }
    }
}
