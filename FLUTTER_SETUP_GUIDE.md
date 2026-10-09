# The Complete Beginner's Guide to Creating, Running, and Distributing a Flutter App

> **Read this first.** This guide is written so that *anyone* — no matter their
> background — can go from a completely blank computer to having their own
> Flutter app running on a phone, and finally **downloadable** (installed on a
> real device or published for the world to install).
>
> It is **universal**: it covers every supported platform (Windows, macOS,
> Linux) and every target device (Android phone, iPhone, emulator/simulator,
> web browser, desktop). Follow only the sections relevant to you — every
> section is clearly labeled so you can skip what you don't need.
>
> Plan for **1–3 hours** for the full setup depending on your internet speed
> (the downloads are large). After that, creating and running a new app takes
> under a minute.

---
## Table of Contents

1. [What You Are Building and What You Need](#1-what-you-are-building-and-what-you-need)
2. [Step 1 — Install the Required Software](#2-step-1--install-the-required-software)
   - [On Windows](#on-windows)
   - [On macOS](#on-macos)
   - [On Linux](#on-linux)
3. [Step 2 — Verify Everything with `flutter doctor`](#3-step-2--verify-everything-with-flutter-doctor)
4. [Step 3 — Install an Editor (VS Code or Android Studio)](#4-step-3--install-an-editor-vs-code-or-android-studio)
5. [Step 4 — Set Up Where Your App Will Run](#5-step-4--set-up-where-your-app-will-run)
   - [Android: a virtual phone (emulator)](#android-a-virtual-phone-emulator)
   - [Android: a real phone (USB or wireless)](#android-a-real-phone-usb-or-wireless)
   - [iOS: a simulator or real iPhone (macOS only)](#ios-a-simulator-or-real-iphone-macos-only)
   - [Web and desktop](#web-and-desktop)
6. [Step 5 — Create Your First Flutter Project](#6-step-5--create-your-first-flutter-project)
7. [Step 6 — Understand the Project You Just Made](#7-step-6--understand-the-project-you-just-made)
8. [Step 7 — Run Your App](#8-step-7--run-your-app)
9. [Step 8 — Make It Yours (Edit the Code)](#9-step-8--make-it-yours-edit-the-code)
10. [Step 9 — Build a Release Version People Can Download](#10-step-9--build-a-release-version-people-can-download)
11. [Step 10 — Put Your App on a Phone (side-loading)](#11-step-10--put-your-app-on-a-phone-side-loading)
12. [Step 11 — Publish Your App Publicly (App Stores)](#12-step-11--publish-your-app-publicly-app-stores)
13. [Common Problems and How to Fix Them](#common-problems-and-how-to-fix-them)
14. [Handy Command Cheat Sheet](#handy-command-cheat-sheet)
15. [Keeping Flutter Up to Date](#keeping-flutter-up-to-date)

---

## 1. What You Are Building and What You Need

**Flutter** is Google's free toolkit for building apps. You write the app **once**
in a language called **Dart**, and Flutter compiles it into a *native* app for
**Android**, **iOS**, **Windows**, **macOS**, **Linux**, and **web browsers** —
all from the same code.

### What you will have at the end of this guide
- The Flutter software installed on your computer.
- A working "Hello World" app (the default counter app) running on a device.
- The ability to edit the app to make it yours.
- A finished **release** file (.apk / .aab for Android, .ipa for iPhone) that
  you can **download** onto a phone or publish to an app store.

### Minimum computer requirements
| Requirement | Recommended |
|---|---|
| Operating system | Windows 10/11 (64-bit), macOS (11+), or a mainstream Linux distro |
| RAM | 8 GB or more (4 GB works but is slow) |
| Free disk space | At least 12 GB after OS (Android SDK + emulator are big) |
| Internet | Required for all the downloads |

### What you need to download (all free)
1. **Flutter SDK** (the toolkit itself).
2. **Android Studio** (provides the Android SDK + virtual phone). Lightest path is the Android **Command-line tools** only, but Android Studio is recommended for beginners.
3. **An editor**: **Visual Studio Code** (light and simple) *or* Android Studio (all-in-one).
4. **Git** (a tool for downloading code packages; Flutter uses it internally).

> **A note on phones:** you do *not* need a phone to start. Flutter can run your
> app in a virtual phone (emulator) on your computer, or right in a web browser.
> A real phone is only needed for **Step 10**.

---

## 2. Step 1 — Install the Required Software

> Do these in order: **Git → Flutter SDK → Android Studio → Java (only if
> Android Studio didn't install it) → Editor**.

### On Windows

#### 2.1. Install Git
1. Go to <https://git-scm.com/download/win> and download the 64-bit installer.
2. Run the installer. Click **Next** through all steps, keeping the defaults.
   (The defaults are safe for beginners.)
3. Verify: open **PowerShell** (press `Win`, type `PowerShell`, press Enter) and
   run:
   ```powershell
   git --version
   ```
   You should see something like `git version 2.40.0`.

#### 2.2. Install the Flutter SDK
1. Go to <https://docs.flutter.dev/get-started/install/windows> and download the
   **Flutter SDK** zip (it is ~1 GB; take the *stable* channel).
2. Move the downloaded **`.zip`** file to a good location on your disk — for
   example `C:\`. Flutter needs a stable path that never moves. **Do not put it
   in `C:\Program Files` or any folder with a space in its name** (this causes
   problems).
3. Unzip it there. You will now have a folder named **`flutter`** containing
   folders such as `bin`, `packages`, and `dev`.
4. Add Flutter to your **PATH** so the computer knows where `flutter` lives:
   - Press `Win`, search for **"Edit the system environment variables"**, open it.
   - Click **Environment Variables…** (bottom right).
   - In the upper list ("User variables"), select **Path**, click **Edit…**,
     then **New**, and add the full path to the `bin` folder inside Flutter:
     ```
     C:\flutter\bin
     ```
   - Click OK on every window.
5. **Close and reopen PowerShell** (so the new PATH is picked up), then run:
   ```powershell
   flutter --version
   ```
   You should see Flutter's version and Dart version. If you get
   `'flutter' is not recognized`, double-check the `bin` path you added.

#### 2.3. Install Android Studio (for the Android part)
1. Go to <https://developer.android.com/studio> and download **Android Studio**
   (Windows 64-bit installer).
2. Run the installer. Keep every default. This installs:
   - Android Studio (the editor — fine, you may use it or ignore it).
   - **Android SDK** (required to build and run Android apps).
   - **Android SDK Command-line tools**.
   - Android Studio itself comes bundled with a modern **Java** (JDK 17+).
3. First launch:
   - A wizard appears. Click **Next / Finish** accepting defaults.
   - It will ask to start downloading the Android SDK — let it.
4. **Accept the Android SDK licenses** (this is a very common first-run roadblock).
   Open a new PowerShell and run:
   ```powershell
   flutter doctor --android-licenses
   ```
   Press `y` (yes) for each license prompt. If this errors about Java, install a
   standalone JDK (see *Troubleshooting* at the end).

#### 2.4. (Optional but recommended) Install Visual Studio Code
1. Go to <https://code.visualstudio.com/download> and install the **Windows**
   build.
2. Open VS Code, press `Ctrl+Shift+X` (extensions panel), search for and install
   two extensions:
   - **Flutter** (from Dart Code)
   - **Dart** (installs automatically with the Flutter extension)
3. That's it — VS Code is now Flutter-ready.

> **You're done with Windows.** Jump to [Step 2 Verification](#3-step-2--verify-everything-with-flutter-doctor).

---

### On macOS

#### 2.1. Install Git
1. Open the **Terminal** app (spotlight: press `Cmd+Space`, type `Terminal`).
2. Run:
   ```bash
   git --version
   ```
   If it's not installed, macOS will prompt you to install *Command Line
   Developer Tools* — click **Install** and wait, then re-run the command.

#### 2.2. Install the Flutter SDK
1. Go to <https://docs.flutter.dev/get-started/install/macos> and download the
   **stable** Flutter SDK zip.
2. Unzip it where you want it to live, e.g.:
   ```bash
   cd ~
   unzip ~/Downloads/flutter_sdk*.zip
   ```
   This creates a `flutter` folder in your home directory.
3. Add it to your PATH. In Terminal:
   ```bash
   echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
   source ~/.zshrc
   ```
   (If you use bash instead of zsh, replace `~/.zshrc` with `~/.bash_profile`.)
4. Verify:
   ```bash
   flutter --version
   ```

#### 2.3. Install Xcode (required for iPhone apps; skip if Android-only)
1. Open the **App Store**, search for **Xcode**, and install it (very large, ~12 GB).
2. Once installed, open Terminal and accept its license + install its tools:
   ```bash
   sudo xcodebuild -license accept
   xcode-select --install
   ```
3. Flutter relies on **CocoaPods** for iPhone dependencies. Install it (requires
   Ruby, which macOS includes):
   ```bash
   sudo gem install cocoapods
   ```
   If the system Ruby is blocked, install via Homebrew instead:
   ```bash
   brew install cocoapods
   ```

#### 2.4. Install Android Studio (optional — needed only to make Android builds)
Follow the [Windows Android Studio section](#23-install-android-studio-for-the-android-part),
downloading the **macOS (Intel or Apple Silicon — pick the one matching your Mac)**
installer instead of the Windows one. Then:
```bash
flutter doctor --android-licenses
```
(press `y` for each).

> **You're done with macOS.** Jump to [Step 2 Verification](#3-step-2--verify-everything-with-flutter-doctor).

---

### On Linux

#### 2.1. Install Git, curl, and a few libraries
Open a terminal. On Debian/Ubuntu-based systems:
```bash
sudo apt update
sudo apt install -y git curl unzip wget xz-utils zip libglu1-mesa libunwind-dev libgconf-2-4 libgtk-3-dev ninja-build libc6 lib32stdc++6
```
(On Fedora/RHEL, the equivalents are `sudo dnf install ... git curl unzip wget
ninja-build gtk3-devel mesa-libGL-devel`.)

#### 2.2. Install the Flutter SDK
```bash
cd ~
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.0-stable.tar.xz
tar xf flutter_linux_*.tar.xz
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
flutter --version
```
> The exact version number in the URL changes over time — copy the current
> stable Linux `.tar.xz` link from
> <https://docs.flutter.dev/get-started/install/linux> if this one is outdated.

#### 2.3. Install Android Studio
Download the Linux installer from <https://developer.android.com/studio>,
unzip it, run `bin/studio.sh`, complete the setup wizard, then:
```bash
flutter doctor --android-licenses
```
(press `y` for each license).

#### 2.4. Enable Linux desktop apps (optional)
```bash
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
flutter config --enable-linux-desktop
```

> **You're done with Linux.** Jump to [Step 2 Verification](#3-step-2--verify-everything-with-flutter-doctor).

---

## 3. Step 2 — Verify Everything with `flutter doctor`

`flutter doctor` is a built-in health check that scans your computer and tells
you exactly what is installed and what is missing. Open your terminal
(PowerShell on Windows, Terminal on macOS/Linux) and run:

```bash
flutter doctor
```

It prints a report like this:

```
[✓] Flutter (Channel stable, 3.x.x, on Windows 11 ...)
[✓] Android toolchain - develop for Android devices (Android SDK ...)
[✓] Chrome - develop for the web
[✓] Visual Studio - develop Windows apps
[✓] Android Studio (version ...)
[✓] Connected device (1 available)
```

### How to read it
| Marker | Meaning |
|---|---|
| `[✓]` | This part is ready. |
| `[✗]` | Something is missing or broken — the report tells you what. |
| `[!]` | Warning — not fatal, but worth reading (e.g. non-ASCII path). |

### Fixing common `flutter doctor` complaints
- **"Android license status unknown"** → run `flutter doctor --android-licenses` and accept everything (`y`).
- **"Android toolchain ... cmdline-tools component is missing"** → in Android Studio open **Settings → Languages & Frameworks → Android SDK → SDK Tools** and tick **Android SDK Command-line Tools**, then apply.
- **"No Xcode or CocoaPods"** (macOS only) → install Xcode and `cocoapods` (see macOS section above).
- **"Visual Studio not installed"** (Windows, only if you want Windows desktop apps) → not needed for normal phone apps; it is safe to ignore.

Run `flutter doctor` again until the sections you care about show `[✓]`.
**Note: take care of missing Android toolchain / Java before continuing, but
"Chrome" and "Windows desktop" warnings can be ignored if you only target your
phone.**

---

## 4. Step 3 — Install an Editor (VS Code or Android Studio)

You have two good choices. Both are free.

### Option A: Visual Studio Code (recommended for beginners)
- Light, fast, and clean.
- Install the **Flutter** extension (and its bundled **Dart** extension) from the
  Extensions panel (`Ctrl+Shift+X` / `Cmd+Shift+X`).
- Open any Flutter project folder and you get: syntax highlighting, auto-complete,
  "hot reload" button, and a **device picker** at the bottom-right corner.

### Option B: Android Studio
- Already installed if you followed Step 1. Heavier but very powerful.
- On first launch it offered to install the **Flutter** and **Dart** plugins —
  if it didn't, go to **File → Settings → Plugins** (macOS: **Android Studio →
  Preferences → Plugins**), search *Flutter*, install it (Dart installs with it),
  and restart Android Studio.
- You can then pick **File → New → New Flutter Project**.

**Pick one editor and stick with it for this guide.** The commands below work in
terminal regardless of which editor you use.

---

## 5. Step 4 — Set Up Where Your App Will Run

Your app needs a "target device." Choose **one** of the following options.
Running on your own **real phone** (Option B) is the most fun and is what most
beginners actually want.

### Android: a virtual phone (emulator)

1. Open Android Studio.
2. Press the hamburger/menu → **Tools → Device Manager** (in newer versions it
   is a phone icon on the right rail).
3. Click **+ → Create Virtual Device**.
4. Pick a phone model — e.g. **Pixel 7** — → **Next** → **Next**.
5. On "System Image", download one of the images it offers, such as
   **Android 14 / API 34**, by clicking the download icon → wait → **Next → Finish**.
6. Your new virtual phone appears in the list. Click the **▶** (play) icon to
   boot it. A window opens showing a phone screen.
7. Verify Flutter can see it:
   ```bash
   flutter devices
   ```
   Your emulator will appear in the list with a name like
   `emulator-5554`.

> **Keep the emulator running** while you do Steps 5–8. You can also start it
> from the terminal with `flutter emulators --launch <id>`.

### Android: a real phone (USB or wireless)
This is how you run the app on *your actual phone*:

1. **Turn on Developer Options** on the phone:
   - Open **Settings → About phone**.
   - Tap **"Build number"** 7 times (you'll see "You are now a developer!").
2. **Turn on USB debugging**:
   - **Settings → System → Developer options → USB debugging** → enable it.
   - (On Samsung: **Settings → Developer options**; on Xiaomi you may also need
     to sign in to a Mi account for developer options.)
3. **Connect** your phone to the computer with a good USB cable.
   - The phone will ask **"Allow USB debugging?"** → tick "Always allow" → **Allow**.
4. Verify Flutter sees it:
   ```bash
   flutter devices
   ```
   Your phone appears (e.g. `SM-G991B ... device`).
5. **Cross-check the phone is detected by the OS directly** (a common pitfall):
   - Windows: open **Device Manager → Portable Devices** (or ADB interface).
     If the phone shows an error, you often need the phone manufacturer's USB
     driver or simply to change the phone's USB mode from *"Charging only"* to
     *"File transfer / MTP"*.
   - macOS/Linux: usually works without extra drivers.

> **Wireless alternative (Android 11+):** enable wireless debugging in Developer
> Options, then in the terminal:
> ```bash
> adb pair <phone-ip>:<pairing-port>
> ```
> (enter the pairing code shown on the phone), then:
> ```bash
> adb connect <phone-ip>:<port>
> ```

### iOS: a simulator or real iPhone (macOS only)
Building for iPhone is only possible **on a Mac**:

1. Open Xcode → **Settings → Platforms**, and install an **iOS Simulator** that
   matches your Xcode version.
2. Open the simulator:
   ```bash
   open -a Simulator
   ```
3. Verify:
   ```bash
   flutter devices
   ```
   You'll see something like `iPhone 15 ... simulator`.

For a **real iPhone**:
1. Connect it with a cable and trust the computer when prompted on the phone.
2. In Xcode, open **Window → Devices and Simulators**, select your phone, and
   tick **"Connect via network"** if desired.
3. To run on the real phone from Flutter you need a free Apple developer
   account and a signing team (see the *Problems* section if you hit
   "No development team"). For your very first app, the **simulator is
   enough**.

### Web and desktop
Flutter can also run your app **without any phone**:
- **Web:** install/re-open Google Chrome, then it appears in `flutter devices`.
  One click runs the app in a browser tab.
- **Windows desktop:** install "Visual Studio" with the "Desktop development
  with C++" workload (Windows), or see the macOS/Linux parts above.

---

## 6. Step 5 — Create Your First Flutter Project

Open your terminal in the folder where you keep projects. For example:

- Windows PowerShell: `cd C:\Users\<you>\Documents`
- macOS/Linux: `cd ~/Documents`

Then run:

```bash
flutter create my_app
```

> Replace `my_app` with the name you want. Rules: lowercase, no spaces, use
> underscores (e.g. `my_first_app`). This is the **Dart package name** — the
> folder name and package name can be changed later, but choosing well now
> saves work.

The command creates a folder `my_app` with a complete, runnable starter app.
Then jump into it:

```bash
cd my_app
```

Optional: to include only the platforms you care about (faster, less clutter):
```bash
flutter create --platforms=android,ios,web my_app
```
(You can add platforms later with `flutter create .` inside the folder.)

---

## 7. Step 6 — Understand the Project You Just Made

Open the `my_app` folder in your editor. The most important files/folders:

```
my_app/
├── lib/
│   └── main.dart          ← THE source code. Where your app is written.
├── android/               ← Android-specific native code + settings.
│   └── app/build.gradle   ← app id ("applicationId") & version.
├── ios/                   ← iOS-specific native code + settings.
├── web/                   ← web-specific files.
├── test/                  ← where automated tests go.
├── pubspec.yaml           ← your app's "ingredients list": name, deps, assets.
└── README.md              ← docs for your project.
```

- **`lib/main.dart`** — this is the file you edit 99% of the time. Every Flutter
  app starts in a function called `main()`, and the `runApp(...)` line launches
  your app's visual tree.
- **`pubspec.yaml`** — declare external packages ("packages" = reusable code
  others wrote, e.g. a camera package). Add one under `dependencies:` and run
  `flutter pub get`.
- **`android/app/build.gradle.kts`** (newer templates) or
  **`android/app/build.gradle`** — set the app's unique package
  `applicationId` (e.g. `com.yourcompany.myapp`) and `versionCode`/`versionName`
  before publishing.

The starter app itself is the classic **counter app**: a screen with a floating
`+` button that counts up. It exists purely to prove everything works.

---

## 8. Step 7 — Run Your App

With your target device connected/booting (Step 4), run:

```bash
flutter run
```

What happens:
1. Flutter fetches packages (`flutter pub get` runs automatically).
2. It **compiles** your app for the connected device (first run takes a while —
   this is normal).
3. The app launches on the device / emulator / browser.
4. Your terminal becomes an **interactive console** with the magic commands:

| Terminal key | What it does |
|---|---|
| `r` | **Hot reload** — instantly apply code edits (milliseconds). |
| `R` | **Hot restart** — fully restart the app, keeping state (seconds). |
| `q` | Quit the app. |
| `w` | (Web) dump widget tree for debugging. |

### If you have several devices connected
Pick one explicitly:
```bash
flutter run -d emulator-5554        # a specific Android emulator
flutter run -d chrome               # web browser
flutter run -d macos                # macOS app (or -d windows / -d linux)
flutter run -d "SM-G991B"           # your phone (use its exact device id)
```
To list all devices: `flutter devices`.

### A note about "untrusted developer" on iPhone simulators
The first time (or after Xcode updates) you may see a dialog. That's Flutter
building the app for a simulator, which is normal and safe; press Allow.

**At this point you have successfully created and run a Flutter app.** Everything
from here on is about making it yours and distributing it.

---

## 9. Step 8 — Make It Yours (Edit the Code)

While `flutter run` is running, edit `lib/main.dart`:

1. Open `lib/main.dart`.
2. Find the text shown on the home screen — change it to your own words (e.g.
   change `'You have pushed the button this many times:'` or the AppBar title).
3. Press **`r`** in the terminal. **Hot reload** pushes your change to the
   running app instantly — this is Flutter's superpower.

Experiment: try replacing the whole `build` method's `return` with something
simple to see instant results:

```dart
@override
Widget build(BuildContext context) {
  return const Scaffold(
    body: Center(
      child: Text('Hello from my app!', style: TextStyle(fontSize: 30)),
    ),
  );
}
```

Press `r` again. That's real app development — it looks exactly like this.

> **After you've customized it**, stop (`q`) and run `flutter run` fresh when
> you start a new session.

---

## 10. Step 9 — Build a Release Version People Can Download

Running via `flutter run` is for development. To give your app to people
(including yourself on a different phone), you build a **release** file.

### Android — the `.apk` file
In your project folder:
```bash
flutter build apk --release
```
When it finishes (first release build is slow), you get:
```
build\app\outputs\flutter-apk\app-release.apk
```
That single file installs on any Android phone.

**Want a smaller file (recommended)?** Build per CPU type — most modern phones
use `arm64`:
```bash
flutter build apk --release --target-platform android-arm64
flutter build apk --release --target-platform android-arm
```
The output files land in the same folder (`app-arm64-release.apk`,
`app-armRelease.apk`).

**Publishing to the Play Store instead?** Google requires an `.aab` bundle:
```bash
flutter build appbundle --release
```
Output: `build\app\outputs\bundle\release\app-release.aab`.

#### Signing your Android app (required for real distribution)
Unsigned apps are flagged and refused by stores. Do this once in your
`android/` setup (the Flutter template already wires it up — you fill in values):

1. Generate a keystore (one-time):
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   (Windows users: `keytool` lives inside Android Studio's Java, e.g.
   `"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"`.)
2. Create `android/key.properties` (**never commit this file to a public
   repository — it contains secrets**):
   ```properties
   storePassword=your-long-random-password
   keyPassword=your-long-random-password
   keyAlias=upload
   storeFile=C:/Users/you/upload-keystore.jks
   ```
3. The template file `android/app/build.gradle.kts` already checks for
   `key.properties` and signs release builds automatically when it exists.
4. Rebuild: `flutter build apk --release`. Check it's signed with:
   ```bash
   apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
   ```

### iPhone — the `.ipa` file (macOS only)
```bash
flutter build ipa
```
A `.ipa` (App Store package) is produced under `build/ios/ipa/`. You upload it
to the App Store via Xcode's **Organizer** (see Step 11).

### Web
```bash
flutter build web
```
The finished site is in `build/web/`. Host it on any static host (GitHub Pages,
Netlify, Vercel) by uploading the contents of that folder.

---

## 11. Step 10 — Put Your App on a Phone (side-loading)

"Side-loading" = installing the `.apk` directly, without an app store. This is
how you (and your friends) download your app.

### Transfer the APK to the phone
1. Grab `app-release.apk` from `build/app/outputs/flutter-apk/`.
2. Get it onto the phone, any of these ways:
   - **USB:** connect the phone, choose *File transfer*, copy the file into
     `Download/`.
   - **Email / chat:** email or send the APK to yourself and open it on the phone.
   - **Cloud:** upload anywhere (Google Drive, etc.) and download it on the phone.
   - **Host it publicly** — see the note below.
3. On the phone, tap the downloaded APK file. If Android asks to allow
   "Install unknown apps", open **Settings** and allow your file manager/browser.
4. Follow the prompts. When done, the app icon appears in the launcher — done!

> **Hosting a download link:** since the APK is just a file, you can put it on
> any static file host and give people a link like
> `https://yourdomain.com/app-release.apk`. It's a direct download. Combine with
> the web build (`build/web`) hosted at the same place for a full "download the
> app from my site" experience. (Note: Google Play and many users will warn
> about "unknown sources" for side-loaded APKs — that's expected and safe if
> the file came from you.)

---

## 12. Step 11 — Publish Your App Publicly (App Stores)

#### Google Play Store
1. Create a **Google Play Developer** account (one-time fee): <https://play.google.com/console>.
2. **Create app → Production**, fill in store listing (name, description,
   screenshots, icons — Flutter's default icon can be replaced in
   `android/app/src/main/res/`).
3. Upload your signed **`.aab`** (from Step 9) in the "App bundle explorer".
4. Complete the **Data safety** and **Content** questionnaires.
5. Choose a **release track** (Production = public; Internal testing = share with
   a few testers before launch). Roll out.
6. Review normally takes hours to a few days.

#### Apple App Store
1. Enroll in the **Apple Developer Program** (annual fee): <https://developer.apple.com/programs/>.
2. Upload the `.ipa`: Xcode → **Window → Organizer** → select the build →
   **Distribute App → App Store Connect**.
3. Configure the app record in **App Store Connect** (name, description,
   screenshots, privacy labels).
4. Submit for review (usually 1–3 days).

Both stores have free "internal testing" paths (Google Play *Internal testing*,
Apple *TestFlight*) so you can hand your app to testers before going public.

---

## Common Problems and How to Fix Them

| Problem | Likely cause / fix |
|---|---|
| `'flutter' is not recognized` | Flutter's `bin` isn't on PATH, or terminal wasn't reopened. Recheck Step 2 PATH. |
| `flutter doctor` shows missing cmdline-tools | In Android Studio: **Settings → Android SDK → SDK Tools** → enable **Command-line Tools**. |
| License errors during Android build | Run `flutter doctor --android-licenses` and accept all. |
| "No connected devices" | Run `flutter devices`. Emulator must be booted; phone must have **USB debugging** on and show up in the OS device list. |
| Very slow first build | Normal — first build compiles all native code. Later builds are fast. |
| App installs but crashes immediately | Usually a debug-only device (e.g. one without Play protections). Reinstall via release build (`flutter build apk --release`) or `adb install`. |
| `adb` doesn't see the phone | Try another USB cable/port, switch phone USB mode to *File transfer*, install manufacturer USB driver (Windows), or use wireless debugging. |
| Gradle/Java errors on Windows | Install a JDK 17 and set `JAVA_HOME`; or in Android Studio use **File → Project Structure → SDK location** to point at the bundled JDK. |
| CocoaPods errors on macOS | `sudo gem install cocoapods` or `brew install cocoapods`; then `cd ios && pod install`. |
| "Signing certificate not found" (macOS/iPhone) | In Xcode: **Runner → Signing & Capabilities → Team** — add your free Apple ID account and select it. |
| Hot reload doesn't change anything | Don't use hot reload for `pubspec.yaml`, `main()`, new files at the top level, or native code. Press `R` (hot restart) instead. |
| Play Store rejects the upload | Make sure you uploaded the **.aab** (not .apk), it's **signed**, and versionCode/name are set and unique. |

---

## Handy Command Cheat Sheet

```bash
flutter --version            # check installation
flutter doctor               # health check of the whole toolchain
flutter devices              # list connected devices/emulators/browsers
flutter emulators            # list created Android emulators
flutter create my_app        # create a new project
flutter pub get              # install dependencies from pubspec.yaml
flutter run                  # run on the selected/first device (r=hot reload)
flutter run -d <device-id>   # run on a specific device
flutter analyze              # static analysis / find problems in code
flutter test                 # run tests in the test/ folder
flutter build apk --release  # release APK for Android
flutter build appbundle --release  # release AAB for the Play Store
flutter build ipa            # release archive for iOS (macOS only)
flutter build web            # static web build
flutter upgrade              # update Flutter to latest (see below)
```

---

## Keeping Flutter Up to Date

Flutter releases new versions frequently. To update:

```bash
flutter upgrade
```

After upgrading, one of your projects may need updated packages — simply run
`flutter pub get` in that project. (You only need to upgrade when you want to;
everything keeps working in the meantime.)

---

*This guide was written for absolute beginners and is kept intentionally free
of platform-specific shortcuts. If something doesn't match exactly (versions,
menu names, and screenshot layouts change over time), the answer is the same
tool Adobe/Google themselves give beginners: run `flutter doctor` and read the
message it prints — it points directly at what is missing.*