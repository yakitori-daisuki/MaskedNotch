# 実装判断と非公開API

## 表示の所有と状態

`DisplayState.mode` はhidden／desktop／lockedです。enabled、ログイン中の自分のconsole、sleep、terminate、対象画面、ロック状態が揃わなければhiddenです。ロックAPIの失敗はlockedだけをhiddenにし、desktopを残します。

`OverlayController` が通常は最大1枚の `BandPanel` を所有します。
Build 7のDesktop版の通常画面では `LayeredBandStack` を所有し、3枚を表示します
（更新時の0.1秒の重なりだけ最大4枚）。詳細は [重ね表示](LAYERED_BANDS.md)。
モードまたは画面geometryが変わると、既存パネル全てをorderOut→closeし、
入れ替え予約を取り消し、ロックSpaceをhideしてから新しいパネルを作ります。
ロック中は最大1枚です。ロックに委譲した同じウィンドウを通常Spaceに戻す処理は使わず、
追加の非公開undelegate APIを避けます。

通知はstartで一度だけ登録、stopで解除します。画面が一時的に見つからない場合を含め、各イベント後だけ3回再読取します。新しいイベント、オフ、sleep、終了でgenerationを更新し、DispatchWorkItemをcancelします。キューに乗っていた処理も実行直前にgenerationを照合し、表示直前に最新のセッションと画面を再取得します。

通常パネルは非アクティブNSPanel、borderless、影なし、クリック透過、canBecomeKey/Main=falseです。2026-09-07 19:07の変更で、NSWindow自体はclear／isOpaque=falseとし、全域を覆うCALayerを不透明sRGB(0,0,0,1)にしました。黒帯のアルファは1です。BlackViewのリサイズはパネルに追従し、色・透明度の暗黙アニメーションは無効です。メニューは別のNSStatusItemです。OSの文字色や壁紙は操作しません。

この変更はWindowServerとの合成経路を比較するための修正候補であり、従来の青い背景を解消したという判定ではありません。オフスクリーン描画試験では、1倍／2倍、初期サイズ／リサイズ後の全ピクセルでRGBA(0,0,0,255)を確認しています。実際のOSメニューバーとの合成は別途実機で確認が必要です。

## 非公開依存：SkyLightBridge

採用元：SkyLightWindow `a28588bc5222b8daf6c4b46afb462a5d31495685`。

| シンボル | 元実装に合わせたSwift C型 | 用途／確認 |
|---|---|---|
| SLSMainConnectionID | `() -> Int32` | 接続ID、正の値を要求 |
| SLSSpaceCreate | `(Int32, Int32, Int32) -> Int32` | 引数connection, 1, 0。正のSpace IDを要求 |
| SLSSpaceSetAbsoluteLevel | `(Int32, Int32, Int32) -> Int32` | ロックSpace 400、戻り値0を要求 |
| SLSSpaceAddWindowsAndRemoveFromSpaces | `(Int32, Int32, CFArray, Int32) -> Int32` | 対象ウィンドウ1個、元実装のflag 7、戻り値0を要求 |
| SLSShowSpaces | `(Int32, CFArray) -> Int32` | ロック表示中だけ、戻り値0を要求 |
| SLSHideSpaces | `(Int32, CFArray) -> Int32` | 元実装コメントの宣言を採用、戻り値0を確認 |

`/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight` をRTLD_NOW/LOCALで開き、すべてのシンボルの存在を検証してから関数ポインタに変換します。失敗途中のhandleも閉じます。APIが存在してもABIや動作の互換性は保証されません。上記は採用版の宣言であり、Appleの公開ABIではありません。

Spaceは最初のロック表示で作り、接続につき最大1個を保持します。オフ／unlock／画面なしでは帯を閉じてSpaceをhideし、空のまま再利用します。毎回Spaceを作るとリソースが蓄積するため避けました。`SLSSpaceDestroy` は採用元に宣言がなく、調査した旧CGSヘッダーも型／戻り値が異なるため追加していません。プロセス終了時のWindowServer接続解放に最終解放を任せます。

hide失敗時でも帯のNSPanelを先に閉じます。以降はロック表示をpoisonedとして停止し、解除後に再起動を案内します。毎回エラーループや新しいSpace生成をしません。

元のSwiftUI／OpenSwiftUI／全画面／最大window level／makeKeyAndOrderFrontは採用しません。Spaceレベル400はロック画面との合成候補であり、セキュリティ表示の上に描画されない保証にはなりません。実機目視と解除試験が必要です。

## 非公開依存：SessionMonitor

- `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked` のDistributedNotificationを使用。Boring Notchの指定コミットで確認した名前です。
- `CGSessionCopyCurrentDictionary` の公開UID／on-console／login-doneキーで自分のログイン済みconsoleを確認します。
- 未公開キー `CGSSessionScreenIsLocked` で現在状態を再同期します。完全な自分のログイン済みconsole辞書でキーが欠けている場合だけ「解除状態」の慣例を使います。今回の通常画面の起動診断で、この経路が動作することを確認しました。辞書欠落、型不一致、別UIDは不明／非表示です。
- 通知は遷移直後に辞書より先行する可能性があるため、直近2秒の通知を優先します。無期限のキャッシュにはしません。
- 公開NSWorkspaceのsession、sleep、wake、画面／Space通知からも読み直します。session resign時はすぐ閉じ、再読取が自分のconsoleを示すときだけ復帰できます。
- OSが通知や辞書の意味を変えると取りこぼす可能性があります。これは権限を広げて回避せず、実機の連続lock/unlock・ユーザー切替試験で検出します。

認証画面の再実装、イベントタップ、キーロガー、スクリーンショット、AX、認証情報の取得はありません。標準アラートもロック／sleep／セッション離脱で中断し、解除後へ延期します。

## 公開APIを使う通常表示の限界

- レベル24相当（`statusBar - 1`）はIce PR #960の背景表示候補を参考にしています。値だけでOSの文字／アイコンの合成順が正しいと判定しません。
- 旧版はSDK上のExposé非表示指定 `.transient` を使いましたが、実際の利用者画像で移行中に帯が縮小して見えることが判明しました。2026-09-07の修正版では通常帯も `.stationary` に変更し、物理画面の上端へ固定します。Mission Control中に必要なOS操作を妨げないかは修正後の実機確認が必要です。
- 通常帯は生成時だけでなく、画面／アプリ／Space変更とその有界再試行時にもOSメニューバーの下に配置します。`CGWindowListCopyWindowInfo` の公開メタデータから、対象displayの上端全幅・mainMenuレベル・Window Server所有のウィンドウを選びます。画像やメニュー文字は読みません。該当ウィンドウが一時的に取れない場合は同じレベルの後方へ置きます。これはOSの文字より上へ黒帯を上げる変更ではなく、青い背景問題が解決した証拠でもありません。
- `.fullScreenNone` は「そのウィンドウをfullscreenにできない」フラグであり、他アプリの全画面判定ではありません。`.fullScreenAuxiliary`を通常帯に付けず、`currentSystemPresentationOptions`のKVOとSpace／アプリ切替通知でも抑止します。複数ディスプレイごとの厳密なfullscreen判定は公開APIだけでは確定しておらず、未検証です。
- プライベートsticky tag、OSの文字色変更、メニューバー背景SPI、壁紙監視、画像解析、pollingは追加しません。

## 受け入れ未完了

通常メニューの読みやすさ、本物のロック画面、空撮／シャッフル、認証操作、セキュリティ表示、sleep、連続lock、Spaces、外部接続は実機チェック表で個別に合格する必要があります。現在の納品は「ビルド・自動テスト・API診断済みの実装」であり、「全仕様の実機受け入れ完了」ではありません。
