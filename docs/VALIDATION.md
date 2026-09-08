# 検証記録 — 2026-09-08更新 (Asia/Tokyo)

## 判定

### 2026-09-08：再発と0.5秒更新の比較

通常画面で青へ戻る症状が再発したと利用者から報告されました。透明度を下げてもグレーに見えるとのことです。期間限定の再描画／表示順比較を実装し、利用者の指示で実行しました。3区間とも完了し、通常動作へ復帰しています。[実測結果](REFRESH_EXPERIMENT.md)。表示の改善とちらつきは利用者の回答待ちで、常駐タイマーとしては採用していません。現在の自動テストはSwiftPM 20件／Xcode 26件、すべて成功です。以下には、それ以前の経過を残します。

### 最新の利用者報告：通常表示が動作

利用者から「なぜか行けました」と報告され、続いてオン／オフをアイコンで区別する依頼がありました。通常画面のノッチ隠しが動作したという利用者報告として記録します。改善した設定・条件は未確認で、以前の青へ戻る症状の再現性、長時間の安定性、ロック画面の受け入れまで合格したという意味ではありません。以下には、それ以前の不合格報告と診断の履歴を残します。

アイコン変更では、保存されたhideNotchに応じて「上端全幅の帯」「中央のノッチ」を切り替え、tooltipと読み上げラベルも更新します。黒帯の描画処理、ウィンドウレベル、OS設定は変更しません。

アイコン変更の確認：Releaseビルド成功、再起動後PID 84954を確認。アプリと同じStatusIcon.swiftからオン／オフの拡大プレビューを生成し、形状を目視確認しました。コピー版アプリとZIPも更新済みです。この変更では自動テストを追加・再実行しておらず、以下の23件は描画処理変更時の結果です。実メニューでのクリック切り替えと読み上げはエージェントから未検証です。

### 19:07 JST：描画処理の修正候補

BandPanelの背景をclear／isOpaque=falseに変更し、全域に不透明の黒いCALayerを置きました。色・透明度の暗黙アニメーションを無効化し、リサイズにも追従します。window levelとOSメニューの下への配置は維持し、文字の上へ黒帯を上げていません。

`./script/test.sh --xcode`：SwiftPM 20件、Xcode 23件が成功。追加試験は、青色を敷いたオフスクリーン描画先に黒帯のCALayerを合成し、初期サイズ／リサイズ後、1倍／2倍の全ピクセルがRGBA(0,0,0,255)になることを検証します。**WindowServerがOSメニューと合成した後の画面は、このテストでは検証していません。**

`MASKED_NOTCH_CONFIGURATION=Release ./script/build_and_run.sh --verify`で修正候補を起動、PID 19098を確認。Releaseのcodesign --verify --strictも成功しました。実機確認用のComputer UseはMasked Notch取得時にtimeoutReachedとなりました。**その後、利用者から「アプリ普通にいじる時になると青く戻ってしまいます」と報告され、この候補でも通常表示は不合格です。** ロック画面は未検証です。新しいOSSコードや非公開API、権限要求は追加していません。

再報告後、開発専用の `swift script/inspect_band_windows.swift` でウィンドウのメタデータだけを確認しました。帯（ID 28126）は上端1800×38pt／level24／alpha1で残り、OSメニューバー（ID187、1800×39pt／level24）が手前でした。帯が消滅したという証拠はなく、OS背景との合成が候補ですが、最終画素や原因の確定ではありません。診断スクリプトは通常アプリに組み込まず、画面画像、アプリの内容、設定、入力を取得しません。

この時点ではシステム設定のGUI確認はComputer Useの利用が許可されず実施できませんでした。
その後、2026-09-09に利用者の提案で読み取り専用APIをコマンドから呼び、
メニューバー背景=false、Reduce Transparency=falseを確認しました。
設定値の確認にGUI操作や利用者による再確認は不要です。
再実行は `./script/build_and_run.sh --inspect`、結果は
`docs/evidence/system-state-20260909.json`。設定の変更だけで必ず直るとは案内しません。

追加の技術参照：Thaw `72afeb2eae937ffbe8f6ec1ea998686df950eda1` の `MenuBarOverlayPanel.swift`。通常帯をlevel24へ置く一方、OS背景と文字を個別のz-orderとして扱えない旨のコメントがあります。[同種のアプリ操作時の背景消失報告](https://github.com/thaw-app/Thaw/issues/844)もあります。これらは現在環境の原因を断定する証拠ではありません。Thawのコードは組み込んでいません。

### 追加の利用者報告：デスクトップの黒帯が維持されない

利用者から、Mission Control（3本指の上スワイプ）で帯らしい影が見えるが、戻ると徐々に青くなるとの報告がありました。**当時のデスクトップ表示は受け入れ不合格でした。** 以下の初期API診断の成功は、この報告を否定するものではありません。

続いて利用者が提示した2枚の画像では、通常時はメニューバーが青く、Mission Controlへの移行途中には左右に余白のある黒い長方形が見えます。2枚目は移行完了後ではない、と利用者から明示されています。これは黒帯の変色を直接示す画像ではなく、通常時と遷移時での合成結果の相違を示す画像です。

05:56 JSTの修正版では、通常パネルをtransientからstationaryに変更し、OSメニューの下への並べ直しを状態更新ごとに適用しました。アプリactivationとパネルのactive-space変化も監視します。window levelは24のままで、メニュー文字の上に上げていません。Core 20件／Xcode 22件は再び全件成功し、Release版を通常起動しました。ウィンドウ情報上はOSメニューが手前、帯がその下です。**その後、利用者から「ダメです。青いままです。」との再報告があり、この修正でもデスクトップ表示は不合格です。** Mission Controlの操作・視認性改善は未検証です。

再報告後もPID 3490が同じRelease成果物から起動していることを確認しました。Ice参照版の通常帯もレベル24でOSメニューバーの下に配置しており、今回の調査では有効な追加修正は特定できませんでした。表示に失敗する試験版は終了しました。壁紙、OS外観、メニューバー設定、ログイン項目は変更していません。今回の変更は検証記録の訂正だけで、アプリの機能修正・再ビルド・テスト再実行はしていません。

報告後の読み取りでは、`SLSGetMenuBarUseBlurredAppearance` はfalse、Reduce Transparencyはfalseでした。起動中の帯は画面上端1800×38pt、レベル24、alpha=1、on-screenでした。同じ上端を占めるWindow Serverのメニューバーはレベル24で帯より手前にあり、Control Centerの各ステータスウィンドウはレベル25でした。これはウィンドウのメタデータであり、各ピクセルの色や合成結果を確認したものではありません。

背景設定が有効だった直前の問題とは区別します。実装中の塗り色は固定sRGB黒で、色を青へ変える処理はありません。利用者画像とウィンドウ情報からはOS側のメニューバー背景に帯が隠れる可能性が考えられますが、合成内部の原因は未確定です。Computer Useによる起動中アプリの画面確認はタイムアウトしました。OSメニューを覆う可能性があるため、レベルを上げる試行やOS設定の自動変更は実施していません。今回の失敗を、すべてのmacOSで壁紙非変更方式が不可能という証明にはしません。

**ソース、Xcodeプロジェクト、ビルド、自動テスト、起動・API診断は用意できています。通常表示は再発が報告され、安定性を満たしていません。ロック表示の必須受け入れも残っています。**

| 段階 | 結果 | 根拠／限界 |
|---|---|---|
| Debugビルド | 成功 | Xcode 26.5／SDK26.5、ad-hoc署名 |
| Releaseビルド | 成功 | 同環境。ローカルad-hoc署名。配布署名ではない |
| アプリ起動 | 成功（Debug／Release） | LaunchServicesで `.app` を起動、PID、delegate起動、メニュー3項目のローカルログ |
| デスクトップのパネル生成 | 成功 | 1800×38pt、visible=true、key=false、mouseIgnored=true |
| デスクトップの純黒表示 | **安定性未達** | 一度動作したとの報告後、青へ戻る症状が再発。0.5秒更新の表示効果は利用者回答待ち |
| SkyLight API統合 | 成功（非表示パネルのみ） | シンボル／connection、Space作成／level／attach／show API／hideが成功。パネルはvisible=false |
| 本物のロック画面表示 | **未検証** | lock中のconsole辞書の意味、通知タイミング、空撮との合成も未確認 |
| OS表示・認証操作 | **未検証** | Touch ID／パスワード／セキュリティ表示を操作・確認していない |
| 15秒自動終了 | 成功 | 撤去→通知解除→終了ログ、後続pgrepで該当プロセスなし |
| ログイン時起動 | **実登録未検証** | 読取はSMAppService.Status.notFound (raw 3)。登録／承認／解除／再ログインは行っていない |

GUI確認はComputer UseでFinderの利用が許可されず実施できませんでした。別の入力／画面取得手段に切り替えて権限を迂回していません。手動確認は [MANUAL_TESTS.md](MANUAL_TESTS.md) へ引き継ぎます。

## ビルド環境と実機環境の区別

- ビルドホスト：macOS 26.6.2、build 25G83。
- Xcode：26.5、build 17F42。
- 使用SDK：macOS 26.5。
- プロジェクトdeployment target：macOS 26.0。
- 起動診断ホスト：同じMacBook Pro、Mac17,7、Apple M5 Max。実機GUIの視認・入力試験は未実施。
- `NSScreen`実測：内蔵displayID 1、active/online、ミラーなし、frame=(0,0,1800,1169)pt、safeTop=38pt、scale=2。
- auxiliary areas：左=(0,1131,790,38)pt、右=(1010,1131,790,38)pt。
- 帯の計算結果：(0,1131,1800,38)pt。物理ピクセル数をポイントに混ぜていない。
- 他のmacOS 26.x、macOS 27以降、他機種での互換性保証はしていない。

シリアル番号、Hardware UUID、認証情報は検証記録へ保存していません。

## 実行したコマンド

```sh
sw_vers
xcodebuild -version
xcodebuild -showsdks
python3 script/generate_project.py
./script/build_and_run.sh --build
./script/build_and_run.sh --probe
./script/test.sh --xcode
./script/build_and_run.sh --probe-backend
MASKED_NOTCH_CONFIGURATION=Release ./script/build_and_run.sh --probe-backend
xcodebuild -project MaskedNotch.xcodeproj -scheme MaskedNotch \
  -configuration Release -derivedDataPath build/DerivedData build
codesign --verify --strict --verbose=2 build/DerivedData/Build/Products/Release/MaskedNotch.app
codesign -d --entitlements - build/DerivedData/Build/Products/Release/MaskedNotch.app
python3 script/check_vendor.py
bash -n script/build_and_run.sh script/test.sh
plutil -lint Resources/Info.plist MaskedNotch.xcodeproj/project.pbxproj
```

最初のビルド環境照会はエージェントのファイル制限により一時キャッシュ警告が出たため、Xcodeのビルドとテストはキャッシュ・署名が利用できる実行コンテキストで行いました。アプリ自体に新しいOS権限を付与する操作は行っていません。

## 自動テスト

- SwiftPM：**20テスト、0失敗**。
- Xcode XCTest（2026-09-08版）：**26テスト、0失敗**。共通の20テスト＋AppKit 3テスト＋試験制御3テストです。
- [Coreテスト記録](evidence/core-tests-summary.txt)
- [Xcodeテスト記録](evidence/xcode-tests-summary.txt)
- 詳細ログ：プロジェクト内 `build/core-tests.log`、`build/xcode-tests.log`。
- xcresult：`build/DerivedData/Logs/Test/`。

位置計算、対象画面なし、外部／非active／ミラー除外、ノッチ情報なし、正負の画面原点、1／1.5／2／3倍表示、端数の外向き丸め、不正値、保存オフ、通知競合、100回の論理lock/unlock、sleep、別セッション、lock backend失敗時のdesktop維持を検証しました。

AppKitテストではパネルを画面に表示せず、透明なホストウィンドウと不透明な黒い描画面、クリック透過・フォーカス禁止・有限レベル・stationary指定を確認しました。19:07版では描画面自体の全ピクセルの黒さとリサイズ試験も追加しました。実際のOSウィンドウとの重なり、画面上の最終ピクセル色、入力経路はテストしていません。

XcodeのAppIntentsメタデータ抽出スキップ警告、およびテストプロセスのOS autoShortcutサービス接続ログがありましたが、テストは成功しました。アプリにApp Intents機能や追加権限を追加していません。

## 起動・SkyLight試験

[採取した最終試験ログ](evidence/runtime-probe.log) は2026-09-07 02:49:52〜02:50:07 JSTの15秒試験です。

加えて、配布用ではないローカルRelease成果物自体でも02:55:33〜02:55:49 JSTに同じ15秒試験を行い、同じAPI診断・通常帯生成・撤去・終了を確認しました。[Release起動ログ](evidence/release-runtime-probe.log)。終了後のプロセス存在確認でも残存なしでした。

順序：アプリ起動→メニュー3項目→シンボル／connection照合→非表示BandPanelでSkyLight attach→パネルcloseとSpace hide→通常desktopパネル生成→15秒後に撤去・終了。

`visible=false`のSkyLightパネルで返り値が成功しても、ロック中のOSシーンで帯が見える証拠にはなりません。`visible=true`のdesktopパネルも、OSの文字より下で純黒に見える証拠にはなりません。この2点を合格へ読み替えないでください。

## 署名・ライセンス

- [Release署名の確認](evidence/release-signature.txt)：ローカル署名の整合性検証。
- DebugはXcodeのget-task-allow付き。Releaseは `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` でデバッグ権限の注入を止めています。
- Developer ID署名、archiveによる配布、notarytool、公証、staple、Gatekeeper配布検証は未実施。
- Vendorの8ファイルを固定コミットのチェックサム記録と照合して一致。
- アプリのResourcesにSkyLightWindowのMIT全文、自作コードのMIT全文、THIRD_PARTY_NOTICESを同梱。
- 実行ターゲットに組み込むOSS由来コードはSkyLightBridgeだけ。パッケージのネットワーク解決はない。

## 未検証・未解決条件

1. 標準空撮・シャッフル・スクリーンセーバの本物のロック画面での表示。
2. Space 400が上端のOS／セキュリティ表示を隠さないこと。隠す場合は不合格で、レベルや配置方針の実機調整が必要。
3. 明暗壁紙・ライト／ダーク外観での文字色。黒い文字が帯に埋もれる条件は解決を確認できていない。
4. Touch ID・パスワード解除、sleepからロック状態への復帰、連続lock/unlockの実機操作。
5. Spaces／Mission Control／fullscreen／Stage Manager、画面構成の変化、クラムシェル、ユーザー切替・logout。
6. ログイン項目の実登録、OS承認、再ログイン。
7. CPU、メモリ、長時間常駐の負荷。定常pollingはないが、実測の低負荷保証はしていない。

これらの必須条件が通るまで、「Masked Notchの全仕様完成」とは判定しません。


## 2026-09-08 A方式の通常版採用

利用者からA/B両方で黒の維持に成功したとの報告を受け、通常版を0.5秒ごとの再描画に変更。短時間の再試験ではアプリ単体CPU（1コア基準）がA約0.15%、B約0.65%だったためAを選択。長時間負荷、OS文字・認証操作、ロック画面の合格を意味しない。通常版のタイマーは比較試験中には無効化する。
