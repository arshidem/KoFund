import 'dart:io';

void main() {
  final file = File('analyze_output_utf8.txt');
  if (!file.existsSync()) return;

  final lines = file.readAsLinesSync();
  final deadNullAwareMap = <String, List<int>>{};
  
  for (final line in lines) {
    if (line.contains('dead_null_aware_expression')) {
      final parts = line.split(' - ');
      if (parts.length >= 2) {
        final location = parts[parts.length - 2];
        final locParts = location.split(':');
        if (locParts.length >= 2) {
          final filePath = locParts[0].trim();
          final lineNum = int.tryParse(locParts[1]) ?? -1;
          if (lineNum > 0) {
            deadNullAwareMap.putIfAbsent(filePath, () => []).add(lineNum);
          }
        }
      }
    }
  }

  for (final filePath in deadNullAwareMap.keys) {
    print('Fixing $filePath');
    final targetFile = File(filePath);
    if (!targetFile.existsSync()) continue;
    
    final fileLines = targetFile.readAsLinesSync();
    var modified = false;
    
    for (final lineNum in deadNullAwareMap[filePath]!) {
      final index = lineNum - 1;
      if (index >= 0 && index < fileLines.length) {
        var strLine = fileLines[index];
        // Clean ?? something
        // Just replacing ` ?? 0` or ` ?? ''` or ` ?? '?'` or ` ?? 'Admin'`
        strLine = strLine.replaceAll(RegExp(r'\s*\?\?\s*0'), '');
        strLine = strLine.replaceAll(RegExp(r"\s*\?\?\s*''"), '');
        strLine = strLine.replaceAll(RegExp(r"\s*\?\?\s*'\?'"), '');
        strLine = strLine.replaceAll(RegExp(r"\s*\?\?\s*'Admin'"), '');
        strLine = strLine.replaceAll(RegExp(r"\s*\?\?\s*Timestamp\.now\(\)"), '');
        
        if (fileLines[index] != strLine) {
          fileLines[index] = strLine;
          modified = true;
        }
      }
    }
    
    if (modified) {
      targetFile.writeAsStringSync(fileLines.join('\n') + '\n');
    }
  }
  print('Done fixing null aware expressions!');
}
