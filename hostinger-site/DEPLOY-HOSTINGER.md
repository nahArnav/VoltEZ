# Deploy VoltEZ on Hostinger

This folder is a complete static download website for:

`https://voltez.arnavpatidar.com`

It does not require Node.js, PHP, a database, or a build command.

## Important release-signing warning

The bundled APK is release-optimized but currently signed with the Android
debug key. Use it for testing the website and installation flow. Before public
distribution, create a permanent release keystore, configure Flutter/Gradle to
use it, rebuild the APK, and replace the file in `downloads/`.

Never commit or upload the keystore, its passwords, `key.properties`, or any
backend API secret to the website directory.

## 1. Create the Hostinger subdomain

1. Sign in to Hostinger hPanel.
2. Open **Websites**.
3. Select **Dashboard** for `arnavpatidar.com`.
4. Search for and open **Subdomains**.
5. Create the subdomain named `voltez`.
6. Keep Hostinger's default directory unless you already have a deliberate
   folder structure.
7. Wait for Hostinger to finish provisioning the subdomain and SSL certificate.

If your root domain uses Hostinger Website Builder instead of regular web
hosting, create the subdomain through the DNS Zone or add it as a separate
website. Hostinger's interface will show the required target.

## 2. Upload this package

1. In hPanel, open the dashboard for the new subdomain.
2. Open **Files → File Manager**.
3. Open the subdomain's `public_html` directory.
4. Upload `voltez-hostinger-package.zip`.
5. Right-click the ZIP and choose **Extract**.
6. If Hostinger extracts it into an extra folder, move the contents of that
   folder directly into `public_html`.
7. Confirm that `public_html/index.html` exists directly. The page will not load
   correctly if `index.html` is nested one directory deeper.
8. Make sure hidden files are shown and confirm `public_html/.htaccess` exists.
9. Delete the uploaded ZIP after extraction if you no longer need it there.

The expected server layout is:

```text
public_html/
├── .htaccess
├── index.html
├── styles.css
├── script.js
├── robots.txt
├── sitemap.xml
├── assets/
│   ├── voltez-logo.png
│   └── fonts/
│       ├── Inter-Regular.ttf
│       └── Outfit-Regular.ttf
└── downloads/
    └── VoltEZ-v1.0.0-build2.apk
```

## 3. Test the deployment

Open each URL in a private/incognito browser window:

1. `https://voltez.arnavpatidar.com/`
2. `https://voltez.arnavpatidar.com/downloads/VoltEZ-v1.0.0-build2.apk`
3. `https://voltez.arnavpatidar.com/robots.txt`

Test the download link on a real Android phone. Confirm that the downloaded
file is approximately 63.4 MB and that Android shows the app name `VoltEZ`.

The expected SHA-256 checksum is:

```text
0aed9de6d2708c71b2d91036e72980c732488ec8740ad1ed026dcd9baf65c638
```

## 4. Publish an update later

For each new release:

1. Increase the Flutter build number in `pubspec.yaml`, for example from
   `1.0.0+2` to `1.0.1+3`.
2. Sign the APK with the same permanent release keystore used for every public
   release.
3. Give the APK a versioned filename such as `VoltEZ-v1.0.1-build3.apk`.
4. Upload it into `public_html/downloads/`.
5. Update both download links, the version/size line, and checksum in
   `index.html`.
6. Upload the updated `index.html`.
7. Test the update over the previously installed production-signed version.

Do not change the Android package ID `com.voltez.app` after public distribution,
and never lose the permanent signing keystore. Android requires the package ID
and signing certificate to match before it will install a new APK as an update.
