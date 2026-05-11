# Replace all print( with debugPrint( and add import if needed
Get-ChildItem lib -Recurse -Filter *.dart | ForEach-Object {
    $path = $_.FullName
    $content = Get-Content $path -Raw -Encoding UTF8
    $hasChanges = $false
    
    # Check if file has print( calls
    if ($content -match '\bprint\(') {
        # Check if debugPrint is already imported
        if ($content -notmatch "import.*debugPrint|from.*foundation") {
            # Check if it already has flutter/foundation import
            if ($content -match "import 'package:flutter/foundation.dart'") {
                # Already has the import, no need to add
            } elseif ($content -match "^import 'package:flutter/material.dart';") {
                # Add debugPrint import after material import
                $content = $content -replace "(import 'package:flutter/material.dart';)", "`$1`nimport 'package:flutter/foundation.dart' show debugPrint;"
                $hasChanges = $true
            } else {
                # Add import at the beginning
                $lines = $content -split "`n"
                $importIdx = 0
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i] -match "^import ") {
                        $importIdx = $i
                    } elseif ($lines[$i] -match "^(class|void|final|const)" -and $importIdx -gt 0) {
                        # Insert before first non-import
                        $lines = $lines[0..$importIdx] + @("import 'package:flutter/foundation.dart' show debugPrint;") + $lines[($importIdx+1)..($lines.Count-1)]
                        $content = $lines -join "`n"
                        $hasChanges = $true
                        break
                    }
                }
            }
        }
        
        # Replace print( with debugPrint(
        $newContent = $content -replace "\bprint\(", "debugPrint("
        if ($newContent -ne $content) {
            $content = $newContent
            $hasChanges = $true
        }
    }
    
    if ($hasChanges) {
        $content | Set-Content $path -Encoding UTF8
        Write-Host "Updated: $path"
    }
}
