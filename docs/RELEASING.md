# Release guide / リリース手順

## One-copy installer / コピペ用インストーラ

The READMEs contain the complete download-and-install command, sourced from `script/install_from_release.sh`. The public experimental release is `v0.1.0-preview.1` (standard app 0.1.0, build 9, arm64). Update the pinned tag in the script and both README commands together for the next release; do not overwrite existing release assets.

日英READMEの「1回のコピペ」は `script/install_from_release.sh` と同じ処理です。公開試用版は `v0.1.0-preview.1`（通常版0.1.0、Build 9、arm64）。次の配布時は新しいタグを発行し、スクリプトと両READMEの取得先を一緒に更新してください。

After publishing, test the exact README command through its verification-only argument to exercise public downloads without installing or launching the app. The equivalent repository command is:

```sh
./script/install_from_release.sh --verify-only
```

これは公開URLからの取得・チェックサム・内蔵アプリ署名までの確認です。実際の配置・更新・起動や、別のMacでの実機検証とは区別してください。

## Build and verify / ビルド・検証

On an Apple Silicon Mac with full Xcode and the macOS 26 SDK:

```sh
./script/test.sh --xcode
python3 script/check_vendor.py
./script/build_unsigned_installer.sh
python3 script/test_localizations.py build/ReleaseDerivedData/Build/Products/Release/MaskedNotch.app
python3 script/test_unsigned_installer.py
```

The build packages the standard app, not the Desktop experiment. It does not install, quit, or launch apps. Python is needed only on the build/test machine.

通常版を配布対象にします。Desktop実験版とはBundle ID・描画方式が異なります。ビルド処理は既存アプリを終了・起動・インストールしません。導入側にPythonは不要です。

## Before distributing / 配布前

- Record the source commit, Xcode version, app version/build, and installer SHA-256.
- Complete relevant [manual tests](MANUAL_TESTS.md). Black-strip recurrence and lock-screen validation remain open. Until resolved, use an experimental prerelease and prominently list these limitations.
- Test fresh installation and upgrade with backup on a separate test Mac/account. Verification-only mode does not test installation, launch, login items, Gatekeeper, or appearance.
- Check both languages, icon, bundled licenses, and code signature.
- Review repository contents before pushing. Never commit credentials, local authentication data, private captures, or build output.

黒帯の再発とロック画面の実機確認は未解決です。安定版と表現せず、実験的なプレリリースとして制約を記載してください。別のテスト環境で新規導入・バックアップを伴う更新を確認します。

## GitHub release / GitHubでの配布

Creating a repository does not automatically publish binaries. Attach both generated assets to the same release:

```text
MaskedNotch-install-unsigned.sh
MaskedNotch-install-unsigned.sh.sha256
```

Include the checksum in the release notes. State that the app is ad-hoc signed and unnotarized. The installer requires explicit consent before removing quarantine from its staged app. Never recommend disabling Gatekeeper or SIP globally.

リポジトリの作成だけではアプリを公開しません。両ファイルを同じReleaseに添付し、SHA-256をリリース本文にも掲載してください。受取側はチェックサム確認後に `bash MaskedNotch-install-unsigned.sh --user --allow-unsigned` で導入できます。

Once a public release exists, link to its exact tag from both READMEs and update the availability notice. Private downloads require authentication. For experimental prereleases, use tag-specific URLs instead of `releases/latest`, which targets full releases.

公開後は日英READMEの「未公開」を更新し、該当タグへのリンクを追加してください。非公開リポジトリからの取得には認証が必要です。プレリリースにはタグを指定したリンクを使います。

## Future notarized releases / 将来の公証版

This workflow deliberately checks for ad-hoc signing. A future notarized release needs a separate packaging path using Developer ID, hardened runtime/entitlement checks, notarization, stapling, and validation on another Mac.

将来Developer ID署名・公証を導入する場合は別の配布経路を用意してください。現在のインストーラを公証版として流用することはできません。
