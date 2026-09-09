# Masked Notch

[English](README.md) | 日本語

ノッチ付き内蔵ディスプレイの上端に黒い帯を表示する、小さなmacOSメニューバーアプリです。SwiftとAppKitで実装し、壁紙・標準空撮・スクリーンセーバの設定は変更しません。

> **試作段階です。** 最初は表示できても黒帯が消える問題があり、3方式を重ねるDesktop実験版を含めて未解決です。本物のロック画面での表示と認証操作も未検証です。ビルドやテストの成功は表示の安定性を保証しません。[開発記録](docs/DEVELOPMENT_STATUS.ja.md)と[実機チェック表](docs/MANUAL_TESTS.md)を参照してください。

## 動作条件

- macOS 26以降、ノッチ付き内蔵ディスプレイを持つApple Silicon Mac。
- ビルド時：macOS 26 SDKを含むフル版Xcode。ローカルではXcode 26.5で確認しています。
- XcodeGen、Homebrewパッケージ、外部Swiftパッケージのダウンロードは不要です。

外部画面、ミラーリング、無効な画面、ノッチのない画面には表示しません。メニューはmacOSの優先言語に従い日本語・英語を選び、対応言語がなければ英語になります。言語を変更したあとは再起動してください。

## ソースからビルド・起動

リポジトリのフォルダで実行します。

ソースの取得は `git clone https://github.com/yakitori-daisuki/MaskedNotch.git`、移動は `cd MaskedNotch` です。この作業フォルダ専用のGitHubアカウント設定は[設定手順](docs/GITHUB_SETUP.ja.md)を参照してください。

```sh
./script/build_and_run.sh --build  # Debugをビルドするだけ
./script/build_and_run.sh --probe # 90秒で自動終了する試験起動
./script/build_and_run.sh         # 通常起動
```

Xcodeで `MaskedNotch.xcodeproj` を開き、`MaskedNotch` スキーム／My Macを選んでRunすることもできます。プロジェクトは生成済みです。`Package.swift` はCoreライブラリとテスト専用で、GUIアプリは生成しません。

Debugの生成物は `build/DerivedData/Build/Products/Debug/MaskedNotch.app` です。Releaseは次のコマンドで作れます。

```sh
MASKED_NOTCH_CONFIGURATION=Release ./script/build_and_run.sh --build
```

生成物は `build/DerivedData/Build/Products/Release/MaskedNotch.app` です。ログイン時起動を試す場合は `~/Applications` など固定した場所にコピーしてください。ビルドのみのモードはアプリの終了・インストール・起動を行いません。起動モードでは既存の `MaskedNotch` プロセスを終了してから起動します。

## 自己完結型インストーラを作る

[Quick3DLook](https://github.com/yakitori-daisuki/Quick3DLook/blob/main/README.ja.md)と同様に、手元でビルドしたアプリを1本のスクリプトへ埋め込み、SHA-256ファイルと一緒に配布する方式です。

```sh
./script/build_unsigned_installer.sh
```

生成物：

- `dist/MaskedNotch-install-unsigned.sh`
- `dist/MaskedNotch-install-unsigned.sh.sha256`

**通常版**のarm64 Releaseをビルドし、ad-hoc署名、Hardened Runtime、アーキテクチャ、リソース、entitlementが空であることを検証してZIPを埋め込みます。A/B・Blink・Desktop実験版は含みません。作成側のアプリのインストール・起動も行いません。受取側はmacOS標準ツールだけで導入でき、Xcode、Homebrew、Apple開発者アカウント、署名証明書は不要です。

### ダウンロードしたビルドをインストール

**公開インストーラのリリースはまだありません。** 以下は2つのファイルを一緒に受け取った場合、または今後のReleaseから取得した場合の手順です。[リリース手順](docs/RELEASING.md)も参照してください。

このビルドは**Developer ID署名・Appleの公証を受けていません**。ad-hoc署名は配布者の本人性を証明しません。配布元を信頼できる場合だけ導入してください。`--allow-unsigned` は、このアプリのquarantine属性を解除することへの明示的な同意です。GatekeeperやSIPの設定は変更しません。同じ配布元のチェックサムは破損・取り違えの検出用であり、配布元自体の侵害に対する独立した証明ではありません。

ダウンロードした2つのファイルがあるフォルダで検証します。

```sh
shasum -a 256 -c MaskedNotch-install-unsigned.sh.sha256
```

`MaskedNotch-install-unsigned.sh: OK` と表示された場合だけ先へ進んでください。実行前にスクリプトの内容を確認できます。Masked Notchと実験版を終了してから導入します。

```sh
bash MaskedNotch-install-unsigned.sh --user --allow-unsigned
```

`~/Applications/Masked Notch.app` に導入します。書き込み可能な `/Applications` へ導入する場合は `--system` を使ってください。`sudo` は使いません。既存アプリは日時付きバックアップとして残します。`--no-open` を追加すると導入後に起動しません。ログイン時起動を自動で有効にすることもありません。

インストール・起動せず、内蔵データと署名だけを検証する場合：

```sh
bash MaskedNotch-install-unsigned.sh --verify-only
```

## 使い方

メニューバーアイコンから「ノッチを隠す」「ログイン時に起動」「このアプリについて」「終了」を選べます。「ノッチを隠す」は初期値オンで、状態を保存します。ログイン時起動は自分で有効にするまで登録しません。承認が必要な場合は、システム設定 → 一般 → ログイン項目と機能拡張を確認してください。Dockアイコンやメインウィンドウはありません。

最初のデスクトップ試験は、システム設定 → メニューバー → **メニューバーの背景を表示：オフ**、アクセシビリティ → ディスプレイ → **透明度を下げる：オフ**で行ってください。アプリは設定を変更しません。この設定だけで再発問題が解決するわけではありません。

壁紙とライト／ダーク外観ごとに、メニュー文字・時計・アイコンが読めてクリックできることを確認してください。アプリはOSのメニュー文字色を制御しません。見えにくい場合は「ノッチを隠す」をオフにするか終了してください。アイコンは保存設定を示し、実際の画面の色を判定するものではありません。

ロック画面ではログイン済みの自分のセッションに限りSkyLightの非公開APIを使います。ログイン前、FileVault解除、別ユーザーのセッションは対象外で、OS更新により使えなくなる可能性があります。まず90秒の試験起動と[実機チェック表](docs/MANUAL_TESTS.md)で確認してください。ロック画面での動作は検証済みの機能ではありません。

## テスト・診断

```sh
./script/test.sh
./script/test.sh --xcode
python3 script/check_vendor.py
python3 script/test_localizations.py build/ReleaseDerivedData/Build/Products/Release/MaskedNotch.app
python3 script/test_unsigned_installer.py # 先にインストーラを生成
./script/build_and_run.sh --inspect       # 読み取り専用。ビルド・起動なし
```

翻訳テストは小さなFoundationプログラムを使い、本体の起動や保存された言語設定の変更を行いません。自動テストは黒帯の見た目、実際のクリック、ログイン項目の登録、認証動作を保証しません。追加の実験と制約は [docs](docs/) に記録しています。

## 削除

「ログイン時に起動」をオフにし、終了してからゴミ箱へ移動します。必要ならmacOSのログイン項目も確認してください。壁紙の復旧は不要です。緊急停止は `pkill -x MaskedNotch` で行えます（実験版も停止します）。不要になったバックアップアプリは手動で削除してください。

## 構成・ライセンス

`Sources/MaskedNotch/` がアプリ本体とロック画面連携、`Sources/MaskedNotchCore/` が位置・表示状態の処理、`Tests/` がCore／AppKitテスト、`script/` がビルド・配布・開発用診断です。

[MITライセンス](LICENSE)。[SkyLightWindow](https://github.com/Lakr233/SkyLightWindow)の固定版の一部を改変しMITで同梱しています。[第三者ソフトウェアの通知](THIRD_PARTY_NOTICES.md)を参照してください。アプリ本体にネットワーク通信や分析機能はありません。画面撮影は別の開発用診断スクリプトだけにあり、アプリには含まれません。
