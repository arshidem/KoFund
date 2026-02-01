$files = @(
  'lib\\features\\admin\\screens\\admin_dashboard.dart',
  'lib\\features\\history\\screens\\history_screen.dart',
  'lib\\features\\programs\\utils\\contribution_receipt_pdf.dart',
  'lib\\features\\programs\\screens\\tabs\\program_participants_tab.dart'
)
foreach ($rel in $files) {
  $path = Join-Path (Get-Location) $rel
  if (Test-Path $path) {
    $lines = Get-Content $path -Encoding UTF8
    $new = $lines | Where-Object { -not ($_ -match '^\s*if\s*\(!mounted\)\s*return;\s*$') }
    if ($new.Count -ne $lines.Count) {
      $new | Set-Content $path -Encoding UTF8
      Write-Host "Removed mounted checks from: $path"
    } else {
      Write-Host "No mounted checks removed in: $path"
    }
  } else {
    Write-Host "File not found: $path"
  }
}
