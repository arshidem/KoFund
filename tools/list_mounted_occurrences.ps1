Get-ChildItem lib -Recurse -Filter *.dart | ForEach-Object {
    $path = $_.FullName
    $lines = Get-Content $path -Encoding UTF8
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'if \(!mounted\) return;') {
            Write-Host ("{0}:{1}: {2}" -f $path, ($i+1), $lines[$i])
        }
    }
}
