// build.js
const fs = require('fs');
const path = require('path');

// Load environment variables from .env file
try {
  require('dotenv').config();
} catch (error) {
  console.log('⚠️ dotenv not found, using process.env directly');
}

// Configuration
const CONFIG = {
  // Read from .env or use defaults
  APP_NAME: process.env.APP_NAME || 'Kofund',
  ANDROID_PACKAGE: process.env.ANDROID_PACKAGE || 'com.kofund.app',
  IOS_BUNDLE_ID: process.env.IOS_BUNDLE_ID || 'com.kofund.app',
  URL_SCHEME: process.env.URL_SCHEME || 'kofund',
  DEEP_LINK_BASE: process.env.DEEP_LINK_BASE || 'https://kofund-153ba.firebaseapp.com',
  FIREBASE_API_KEY: process.env.FIREBASE_API_KEY || '',
  FIREBASE_PROJECT_ID: process.env.FIREBASE_PROJECT_ID || '',
  FIREBASE_WEB_CLIENT_ID: process.env.FIREBASE_WEB_CLIENT_ID || ''
};

// File paths
const TEMPLATE_PATH = path.join(__dirname, 'web', 'index.template.html');
const OUTPUT_PATH = path.join(__dirname, 'web', 'index.html');

// Check if template exists
if (!fs.existsSync(TEMPLATE_PATH)) {
  console.error(`❌ Template file not found: ${TEMPLATE_PATH}`);
  console.log('📝 Please create web/index.template.html');
  process.exit(1);
}

// Read the HTML template
let html = fs.readFileSync(TEMPLATE_PATH, 'utf8');

// Replace all environment variable placeholders
const replacements = {
  '${APP_NAME}': CONFIG.APP_NAME,
  '${ANDROID_PACKAGE}': CONFIG.ANDROID_PACKAGE,
  '${IOS_BUNDLE_ID}': CONFIG.IOS_BUNDLE_ID,
  '${URL_SCHEME}': CONFIG.URL_SCHEME,
  '${DEEP_LINK_BASE}': CONFIG.DEEP_LINK_BASE,
  '${FIREBASE_API_KEY}': CONFIG.FIREBASE_API_KEY,
  '${FIREBASE_PROJECT_ID}': CONFIG.FIREBASE_PROJECT_ID,
  '${FIREBASE_WEB_CLIENT_ID}': CONFIG.FIREBASE_WEB_CLIENT_ID
};

Object.keys(replacements).forEach(key => {
  html = html.replace(new RegExp(key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), replacements[key]);
});

// Write the final HTML
fs.writeFileSync(OUTPUT_PATH, html);

console.log('✅ Environment variables injected successfully!');
console.log('📁 Output file:', OUTPUT_PATH);
console.log('\n📋 Configuration:');
console.log('  App Name:', CONFIG.APP_NAME);
console.log('  Android Package:', CONFIG.ANDROID_PACKAGE);
console.log('  iOS Bundle ID:', CONFIG.IOS_BUNDLE_ID);
console.log('  URL Scheme:', CONFIG.URL_SCHEME);
console.log('  Deep Link Base:', CONFIG.DEEP_LINK_BASE);
console.log('  Firebase Project:', CONFIG.FIREBASE_PROJECT_ID);
console.log('\n🚀 Run "flutter build web" to build your app');