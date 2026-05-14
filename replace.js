const fs = require('fs');
const path = require('path');

function processFile(filePath) {
    if (!filePath.endsWith('.dart')) return;
    
    let content = fs.readFileSync(filePath, 'utf-8');
    if (!content.includes('ScaffoldMessenger.of')) return;
    
    let modified = false;

    while (true) {
        let index = content.indexOf('ScaffoldMessenger.of');
        if (index === -1) break;
        
        let showSnackBarIdx = content.indexOf('showSnackBar(', index);
        if (showSnackBarIdx === -1) break;

        // Start matching from showSnackBar(
        let startIdx = showSnackBarIdx + 'showSnackBar'.length;
        let pCount = 0;
        let endIdx = -1;

        for (let i = startIdx; i < content.length; i++) {
            if (content[i] === '(') pCount++;
            if (content[i] === ')') {
                pCount--;
                if (pCount === 0) {
                    endIdx = i;
                    break;
                }
            }
        }

        if (endIdx === -1) {
            // Unmatched brackets somehow, break to avoid infinite loop
            break;
        }

        // Check if there is a trailing semicolon to replace as well
        let replaceTill = endIdx + 1;
        let nextSemicolon = content.indexOf(';', endIdx);
        if (nextSemicolon !== -1) {
            let between = content.slice(endIdx + 1, nextSemicolon);
            if (between.trim() === '') {
                replaceTill = nextSemicolon + 1;
            }
        }

        let innerContent = content.slice(startIdx + 1, endIdx);
        
        // If it doesn't contain 'SnackBar', it's probably not a real SnackBar or a variable reference.
        // We skip those since we can't extract the text cleanly.
        if (!innerContent.includes('SnackBar')) {
            // It's a variable or something else. We just remove 'ScaffoldMessenger.of' from our lookup by replacing it temporarily
            content = content.slice(0, index) + '___SCAFFOLD_MESSENGER_SKIP___' + content.slice(index + 20);
            continue;
        }

        let isSuccess = innerContent.includes('Colors.green') || innerContent.includes('success');
        let isError = innerContent.includes('Colors.red') || innerContent.match(/error|fail|delete/i);
        let isWarning = innerContent.includes('Colors.orange') || innerContent.includes('Colors.amber');

        let helperMethod = 'showInfo';
        if (isSuccess && !isError) helperMethod = 'showSuccess';
        else if (isError) helperMethod = 'showError';
        else if (isWarning) helperMethod = 'showWarning';

        // Extract message
        let rawMessage = "'Notification'";
        let contentIdx = innerContent.indexOf('content:');
        if (contentIdx !== -1) {
            let textIdx = innerContent.indexOf('Text(', contentIdx);
            if (textIdx !== -1) {
                let txtStart = textIdx + 'Text'.length;
                let txtPCount = 0;
                let txtEnd = -1;
                for (let i = txtStart; i < innerContent.length; i++) {
                    if (innerContent[i] === '(') txtPCount++;
                    if (innerContent[i] === ')') {
                        txtPCount--;
                        if (txtPCount === 0) {
                            txtEnd = i;
                            break;
                        }
                    }
                }
                if (txtEnd !== -1) {
                    rawMessage = innerContent.slice(txtStart + 1, txtEnd);
                }
            }
        }

        let replacement = `SnackbarHelper.${helperMethod}(context, ${rawMessage});`;
        if (replaceTill !== nextSemicolon + 1) {
            replacement = replacement.replace(';', ''); // if no semicolon originally
        }

        content = content.slice(0, index) + replacement + content.slice(replaceTill);
        modified = true;
    }

    // Restore skipped regions
    content = content.split('___SCAFFOLD_MESSENGER_SKIP___').join('ScaffoldMessenger.of');

    if (modified) {
        if (!content.includes("import 'package:kofund/core/utils/snackbar_helper.dart';")) {
            let importRegex = /import\s+['"][^'"]+['"];/g;
            let lastMatchInfo = null;
            let matchInstance;
            while ((matchInstance = importRegex.exec(content)) !== null) {
                lastMatchInfo = matchInstance;
            }

            if (lastMatchInfo) {
                let insertPos = lastMatchInfo.index + lastMatchInfo[0].length;
                content = content.slice(0, insertPos) + "\nimport 'package:kofund/core/utils/snackbar_helper.dart';" + content.slice(insertPos);
            } else {
                content = "import 'package:kofund/core/utils/snackbar_helper.dart';\n" + content;
            }
        }
        fs.writeFileSync(filePath, content);
        console.log(`Updated ${filePath}`);
    }
}

function walkDir(dir) {
    fs.readdirSync(dir).forEach(f => {
        let dirPath = path.join(dir, f);
        let stat = fs.statSync(dirPath);
        if (stat.isDirectory()) {
            walkDir(dirPath);
        } else {
            processFile(dirPath);
        }
    });
}

walkDir("C:/FlutterApps/kofund/lib");
