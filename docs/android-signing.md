# Android signing and where saves live

Two things decide whether a player keeps their characters across an update.
Both were wrong before v0.1.9, and between them they destroyed every character
on every Android device that took the v0.1.8 update.

## 1. Every release must be signed with the same key

Android refuses to install an APK over one signed by a different key. The only
way past it is to uninstall first — and uninstalling deletes the app's private
storage, which is where characters were kept.

The release workflow used to run `keytool -genkeypair` on every build, so every
release was signed by a different, randomly generated key. Nobody could ever
update in place.

The workflow now restores one fixed key from repository secrets and **fails the
build if it is missing**, rather than quietly generating a throwaway one.

### Creating the key (once, and never lose it)

```bash
keytool -genkeypair -v \
  -keystore release.keystore \
  -alias wilmer \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass '<choose-a-password>' -keypass '<same-password>' \
  -dname "CN=Wilmer Alternity Sidekick, O=rigoparis, C=US"
```

Back `release.keystore` up somewhere you will still have in five years. If it is
lost, no future build can ever update an existing install: every player has to
uninstall and lose their saves again.

### Adding the secrets

```bash
base64 -w 0 release.keystore          # the value for ANDROID_KEYSTORE_BASE64
keytool -list -v -keystore release.keystore -alias wilmer | grep 'SHA256:'
```

The release check compares fingerprints with colons and case stripped, so the
keytool form (`19:F4:AD:...`) and the apksigner form (`19f4ad...`) both work.

The key in use was created on 2026-10-19 (alias `wilmer`, PKCS12, RSA 4096,
certificate SHA-256 `19f4add40c2670aa42f68cc5e3c5ed87749fa42a83343c94426ce40e569d7259`).
The keystore and its password are kept off the repository; the secrets above
hold the only other copy.

Under **Settings → Secrets and variables → Actions**, add:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | the base64 blob from above |
| `ANDROID_KEYSTORE_ALIAS` | `wilmer` |
| `ANDROID_KEYSTORE_PASSWORD` | the password you chose |
| `ANDROID_KEYSTORE_SHA256` | the `SHA256:` fingerprint, optional but recommended |

`ANDROID_KEYSTORE_SHA256` makes the build verify what it actually signed and
fail if the certificate is not the expected one, so a mistake here cannot reach
players a second time.

### The one remaining migration

Moving from a throwaway-key build to the fixed-key build is still a signature
change, so **players must uninstall once more to install v0.1.9**. That is
unavoidable — the old installs were signed by keys that no longer exist.

Tell them to export first: open each hero and tap **Share**. In v0.1.8 that
copies the JSON to the clipboard and opens Android's save picker; saving the
file to Downloads (or pasting the text into a chat) keeps a copy outside the
app. After reinstalling, **Import Hero** takes either back, one hero at a time.

From v0.1.9 **Share** opens an Export dialog with two explicit choices:
**Save as file...** (the system picker, writing a plain `.json` wherever the
player points it) and **Copy as text**.

After that one migration, updates install in place and keep everything.

## 2. Where saves live

`user://` on Android is the app's private storage, deleted on uninstall. From
v0.1.9 characters are written to a folder in shared storage instead:

```
Documents/WilmerAlternitySidekick/
```

It survives uninstall, and it is visible in any file manager so a player can
copy or back up their heroes themselves.

The folder is used **only once storage access is granted**: All files access
on Android 11+, or the older write permission on Android 10 and below.
Writability alone is not enough. Android 11+ lets any app create files in
Documents without a permission, but an app only owns what *this install*
created — after a reinstall the files are still there and the app cannot read
them. A write probe would pass and the heroes would silently vanish later.

The system never grants that permission by itself, so the character list shows
a notice while heroes are in private storage, with a **Keep heroes on this
phone** button. On Android 11+ it opens the All files access settings page;
coming back to the app re-checks, and if access was granted the live store
moves (`CharacterStore.relocate()`) and copies every hero across. If it is
refused the app keeps saving privately and the notice says to export first.

`adopt_legacy_saves()` copies rather than moves, so the originals stay put.

Exporting needs no permission at all: the save picker is the Storage Access
Framework, which writes wherever the player chooses.

Desktop is unchanged: `user://` there already survives uninstall and is an
ordinary folder.

### Still to verify on a real device

The shared-storage path has only been tested through
`resolve_directory()` on desktop. Before announcing v0.1.9, install the APK on
an Android 11+ phone and confirm:

- the storage notice appears on first launch, and **Keep heroes on this phone**
  opens the All files access page;
- granting it and pressing back moves the heroes: the notice disappears and
  they are in `Documents/WilmerAlternitySidekick/` in a file manager;
- they are still there after uninstalling and reinstalling (re-grant access on
  the fresh install and they reappear in the list);
- refusing the permission keeps saving to `user://` and shows the
  "export first" note rather than failing;
- **Share → Save as file...** writes a `.json` to Downloads, and **Import Hero
  → Load from file...** reads it back.
