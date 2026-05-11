Steps to enable Android App Links for kofund.app

1) Build a release-signed APK / AAB and obtain the SHA256 certificate fingerprint:

   Replace `<path-to-keystore>` and `<alias>` with your signing keystore and alias.

   ```bash
   keytool -list -v -keystore <path-to-keystore> -alias <alias>
   ```

   Look for the `SHA256` fingerprint in the output and copy it.

2) Replace `REPLACE_WITH_APP_SHA256_CERT_FINGERPRINT` in `docs/assetlinks.template.json` with that SHA256 value.

3) Host the resulting JSON at:

   `https://kofund.app/.well-known/assetlinks.json`

   - If you control the web hosting for `kofund.app`, create the `.well-known` folder at the site root and upload the file.
   - If using Firebase Hosting, add the file to the `public` folder and use `firebase.json` rewrite/static configuration so it is served at the exact path.

4) Verify App Links on Android:

   - Install the app on a device running Android 6.0+ and trigger a link like `https://kofund.app/invite/<code>`.
   - Alternatively, use `adb` to check verification:

   ```bash
   adb shell pm get-app-links com.kofund.app
   ```

Notes:
- `autoVerify` in the app manifest will make Android attempt to verify the domain at install time. If verification fails, links will still open the web.
- For iOS, implement Universal Links by hosting an `apple-app-site-association` file on the domain.
