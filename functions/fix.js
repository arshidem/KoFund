const fs = require('fs');
let content = fs.readFileSync('templates.js', 'utf8');
content = content.replace(/\\`/g, '`');
content = content.replace(/\\\$/g, '$');
fs.writeFileSync('templates.js', content);
console.log('Cleaned templates.js');
