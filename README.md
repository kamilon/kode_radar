# Kode Radar

[![PR Validation](https://github.com/kamilon/kode_radar/actions/workflows/pr-validation.yml/badge.svg)](https://github.com/kamilon/kode_radar/actions/workflows/pr-validation.yml)

Kode Radar is a lightweight Flutter application for tracking repositories hosted on GitHub and Azure DevOps. A core design principal for Kode Radar is that all user secrets are stored locally on all platforms. This is to ensure the application is safe to use for both personal and enterprise use cases. Kode Radar does not have any backend service and doesn't do any tracking.

The repository contains multiplatform targets currently supporting:

* Android
* iOS
* macOS
* Linux
* Windows

This project has been verified to build and run for the following targets:

- [ ] Android
- [ ] iOS
- [x] macOS
- [ ] Linux
- [ ] Windows

Note: This project has been almost entirely AI generated. I don't recommend using the project as a model for code style, Flutter architecture/design or best practices.

---

## Prerequisites

- Flutter SDK (compatible version for this project)
- Platform toolchains for the targets you are building (Android SDK/NDK, Xcode for iOS/macOS, CMake for Linux, Visual Studio for Windows)

### Linux-specific Dependencies

For Linux builds, the following system packages are required for system tray functionality (tray_manager package):

```bash
sudo apt-get update
sudo apt-get install -y ninja-build libgtk-3-dev libayatana-appindicator3-dev
```

**Alternative packages:** If `libayatana-appindicator3-dev` is not available on your distribution, you can try:
```bash
sudo apt-get install -y ninja-build libgtk-3-dev libappindicator3-dev
```

These dependencies are needed because the `tray_manager` Flutter package requires system tray libraries to create and manage the application's system tray icon.

---

## Configurable build properties

To remove hardcoded identifiers from the source tree, all platforms read a couple of important build configuration settings from environment variables:

- **APP_BUNDLE_ID** - The application/bundle identifier (e.g., `com.yourcompany.kode_radar`)
- **APP_COMPANY** - Company name used in copyright notices (e.g., `YourCompany`)

These values have sensible defaults (`com.example.*`) that do not contain any organization-specific strings. You should override them locally or in CI with values appropriate for your organization.

---

## How to build

**All platforms**

Set environment variables before building:

```bash
export APP_BUNDLE_ID=com.yourcompany.kode_radar
export APP_COMPANY=YourCompany
```

Then build for your target platform:

```bash
flutter build apk --release          # Android APK
flutter build appbundle --release    # Android App Bundle  
flutter build ios --release          # iOS
flutter build macos --release        # macOS
flutter build linux --release        # Linux
flutter build windows --release      # Windows
```

**Per-machine setup (recommended)**

Add the exports to your shell profile (~/.zshrc, ~/.bashrc) for permanent local configuration:

```bash
echo 'export APP_BUNDLE_ID=com.yourcompany.kode_radar' >> ~/.zshrc
echo 'export APP_COMPANY=YourCompany' >> ~/.zshrc
source ~/.zshrc
```

**Windows PowerShell**

For Windows, use PowerShell to set environment variables:

```powershell
$env:APP_BUNDLE_ID = "com.yourcompany.kode_radar"
$env:APP_COMPANY = "YourCompany"
flutter build windows --release
```

**CI / automated builds**

In CI (GitHub Actions, GitLab CI, etc.) set these values as environment variables or secrets:

```yaml
# GitHub Actions example
- name: Build releases
  env:
    APP_BUNDLE_ID: ${{ secrets.APP_BUNDLE_ID }}
    APP_COMPANY: ${{ secrets.APP_COMPANY }}
  run: |
    flutter build apk --release
    flutter build ios --release --no-codesign
```

Store any sensitive values (API tokens, signing keys) in the CI provider's encrypted secrets store — never commit them to the repository, even in your personal branches.

---

## Contributing

You can contribute to this project by creating `Issue`(s) with feature requests and bug reports. You can optionally also create a `Pull Request` against a filed `Issue`. The PR Validation Workflow described below must pass before merging will be permitted and in most cases before the `Pull Request` is reviewed.

This repository includes comprehensive GitHub Actions workflows for continuous integration and pull request validation.

### PR Validation Workflow

The `pr-validation.yml` workflow automatically runs on all pull requests and includes:

#### Code Quality Checks
- **Dart/Flutter formatting validation** - Ensures consistent code style
- **Static analysis** - Runs `flutter analyze --fatal-infos` to catch potential issues
- **Unit tests** - Executes all tests with coverage reporting
- **Coverage reporting** - Uploads coverage data to Codecov

#### Multi-Platform Builds
All supported platforms are built automatically to ensure compatibility:

- **Android** - Builds both APK and App Bundle formats
- **iOS** - Builds without code signing for CI validation
- **macOS** - Desktop application build without code signing for CI validation
- **Linux** - Desktop application build with GTK dependencies
- **Windows** - Desktop application build

---

## App Icon Management

The app uses a single source icon located at `assets/app_icon.png` (1024x1024 PNG). Platform-specific icons are generated automatically using the `flutter_launcher_icons` package and should not be committed to version control.

**To regenerate app icons after changing the source icon:**

```bash
dart run flutter_launcher_icons
```

The app icon configuration is in `pubspec.yaml` under the `flutter_icons` section.
