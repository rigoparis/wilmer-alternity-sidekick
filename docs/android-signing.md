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

Tell them to export first: open each hero, use **Share** (it copies the JSON and
writes a file to Downloads), and use **Import Hero** after reinstalling.

After that one migration, updates install in place and keep everything.

## 2. Where saves live

`user://` on Android is the app's private storage, deleted on uninstall. From
v0.1.9 characters are written to a folder in shared storage instead:

```
Documents/WilmerAlternitySidekick/
```

It survives uninstall, and it is visible in any file manager so a player can
copy or back up their heroes themselves.

`CharacterStore.resolve_directory()` falls back to `user://` whenever that
folder cannot be written — Android 11+ only allows it with the **All files
access** permission, which the system does not grant automatically. If the
permission is refused the app still saves, just back in private storage. On
first launch after the move, `adopt_legacy_saves()` copies anything still in
`user://` across; it copies rather than moves, so the originals stay put.

Desktop is unchanged: `user://` there already survives uninstall and is an
ordinary folder.

### Still to verify on a real device

The shared-storage path has only been tested through
`resolve_directory()` on desktop. Before announcing v0.1.9, install the APK on
an Android 11+ phone and confirm:

- characters written to `Documents/WilmerAlternitySidekick/` are visible in a
  file manager;
- they are still there after uninstalling and reinstalling;
- refusing the storage permission falls back to `user://` and the app still
  saves rather than failing.
