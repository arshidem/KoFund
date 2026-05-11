Get-ChildItem -Path lib -Recurse -Filter *.dart | ForEach-Object {
    $path = $_.FullName
    $hasMounted = Select-String -Path $path -Pattern 'if\s*\(!mounted\)\s*return;' -Quiet
    if ($hasMounted) {
        $isState = Select-String -Path $path -Pattern 'extends\s+State' -Quiet
        if (-not $isState) {
            $lines = Get-Content $path -Encoding UTF8
            $new = $lines | Where-Object { -not ($_ -match '^\s*if\s*\(!mounted\)\s*return;\s*$') }
            if ($new.Count -ne $lines.Count) {
                $new | Set-Content $path -Encoding UTF8
                Write-Host "Removed mounted check from: $path"
            }
        }
    }
}
