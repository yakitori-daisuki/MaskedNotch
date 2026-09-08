# デスクトップ背景の前に置く版 — Build 6

これはBuild 5〜6の記録です。現在は[Build 7の重ね表示](LAYERED_BANDS.md)へ更新し、
利用者から黒帯と文字・アイコンを確認したとの報告を得ています。

## コマンドによる設定確認（2026-09-09 00:33 JST）

利用者からコマンドでの確認を提案され、GUIを使わず現在値を取得した。
前節までのComputer Use未承認は、設定値の読み取り自体を妨げるものではない。
Thawとの比較は保留とし、その回答を以降の診断の前提にしない。

- `SLSGetMenuBarUseBlurredAppearance` はfalse（メニューバー背景オフ）。
- 公開APIでReduce Transparency・Increase Contrast・Reduce Motionはいずれもfalse。
- `_HIHideMenuBar=false`、`AppleInterfaceStyle=Dark`。
- `NSGlassDiffusionSetting=true`。背景表示とは別の設定値として記録し、混同しない。
- Desktopの `hideNotch=true`、Build 6、PID 71830、アプリ非表示=false。
- 帯ID 42155、on-screen=true、alpha=1、level=−1、位置(0,0)、1800×38ポイント。
  内蔵画面はactive/online、ミラーリングなし、safeTop=38。
- 23:13:47の起動以降のLifecycle記録は起動と帯作成の2件のみ。

再実行可能な `./script/build_and_run.sh --inspect` を追加した。
既存アプリの終了・再起動・再ビルド前に分岐し、設定と自作ウィンドウ情報だけを
JSONで出力する。SPI未対応・接続不成立時は不明を返す。
実行成功、シェル構文、実行前後でPIDが同じことを確認した。
今回、壁紙・設定・インストール済みアプリを変更していない。

結果は `docs/evidence/system-state-20260909.json`。
設定値と位置の確認はできたが、最終画素の色は未計測で、表示不具合は未解決。

## Build 6でも表示失敗（2026-09-09 JSTに記録）

更新後、利用者から「隠れてないです」と報告された。Build 6を修正版として
成功扱いにしない。調査後もインストール済みはBuild 6で、さらに別の版へは差し替えていない。

- 保存設定は `hideNotch=true`。23:13:47の起動以降のLifecycleログには
  オフ操作、帯の撤去、終了の記録がなく、同じPID 71830が稼働していた。
- 23:41〜23:46の診断ログには通常デスクトップの更新と黒い1×1画像の提出が継続している。
  これはアプリ内の処理であり、WindowServerが最終画面に黒を表示した証拠ではない。
- 調査後も帯のID 42155、level=−1、alpha=1、上端1800×38ポイントを確認した。
  OSメニューとThawの背景パネルはその前面にある。ウィンドウのalpha値から、
  内部の画素が不透明か、今回の原因かを判断することはできない。
- Thawを設定変更なしで約60秒停止し、自動で再起動した。
  PID 87446の復帰を確認。停止中の黒帯の見え方は利用者回答待ちで、
  Thawの干渉を肯定・否定できる結果はまだ得られていない。
- Computer Useでは本アプリの取得がタイムアウトし、システム設定へのアクセスも
  承認されなかったため、現在の画面の直接確認はできていない。

今回の情報から、設定が勝手にオフになったことを再発原因とは説明できない。
OS側の背景合成は候補だが確定していない。黒帯のレベル変更だけで安定化できる
とも、壁紙を変更せずに実現する方法がすべて不可能とも結論づけない。
壁紙、Thaw設定、ログイン時起動設定は変更していない。

証拠：`docs/evidence/desktop-build6-failure-lifecycle.log`、
`docs/evidence/desktop-build6-failure-windows.log`。
詳細な描画ログは `build/desktop-build6-failure.log`。

## Build 6：再発に対する配置変更（2026-09-08 23:13 JST）

Build 5で利用者から再発と「オン／オフしても変わらない」と報告された。
再発時にも設定はオン、黒帯はレベル−2147483622で存在していた。
ただしOSの上端99ポイントのウィンドウ（−2147483602）とFinderはその上にあった。
この補助背景が黒帯を覆う可能性に対する回避候補として、Desktop版のレベルを
`NSWindow.Level.normal - 1`（−1）へ変更した。メニューへの相対配置は行わない。
これにより壁紙・Finder・上端補助背景より上、通常アプリ・OSメニューより下になる。
OSメニュー側が独自に壁紙を合成する場合まで解決したという証拠はない。

通常起動でも `Lifecycle` カテゴリで起動時の設定、メニューのオン／オフ操作、
帯の作成、撤去時の状態条件、終了を記録する。今回の起動はさらに
`--diagnostics` を指定し、各更新時のセッション・画面状態と描画提出を記録する。
壁紙・Thaw設定・ログイン時起動設定は変更していない。点滅・定期再描画も追加していない。

Core 20件・Xcode 32件、Releaseビルド、署名検証に成功。
`/Applications/Masked Notch Desktop.app` をBuild 6へ更新し起動した。
23:13:47のログでlevel=−1、visible=true、activeSpace=true、hideNotch=trueを確認。
公開ウィンドウ一覧でもOS上端補助背景より上へ移ったことを確認した。
この時点では目視確認待ちだったが、その後利用者から表示失敗が報告された（上記）。
配置・起動の証拠は `docs/evidence/desktop-build6-*.log`。
Build 5は `build/Backups/` に保存した。

## 以下はBuild 5の経緯

**利用者から「うまくいけてる」と動作報告があり、2026-09-08に `/Applications/Masked Notch Desktop.app` へ移動して起動しました。**
旧 `/Applications/MaskedNotch.app` は利用者の依頼でゴミ箱へ移動済みです。
移動後の署名と起動元を確認しました。壁紙の画像・動画・設定は変更していません。
以下の「目視未確認」はエージェント側の検証範囲です。利用者報告は成功として記録し、
ロック画面や長時間・全条件の受け入れとは区別します。

利用者の「メニューバーの後ろ、壁紙の前に黒帯を置く」という提案に基づく比較版。
通常画面はAppKitのNSPanel、ロック画面は従来のSkyLight Spaceを使う。
両方を同時に重ねず、現在の表示モードに応じて最大1枚の帯を切り替える。

## 通常版との差

- 通常版は `statusBar - 1`（このMacでは24）で、OSメニュー直下へ相対配置する。
- Desktop版は `CGWindowLevelForKey(.desktopWindow) + 1`（このMacでは−2147483622）。
  壁紙のレベル直上、Finderのデスクトップアイコンや通常ウィンドウより下に置く。
- Desktop版は起動時もイベント後の再配置時も、その階層内で前へ出す。
  メニューへの相対配置を呼んでレベル24へ戻してしまう処理は使わない。
- Desktop版では点滅・0.5秒周期の再描画を行わない。画面／Space／セッション等の
  通知と既存の有限回の再試行で配置・描画を更新する。
- ロック用パネルは従来のレベルとSkyLight Spaceを使う。
- 壁紙のファイル、動画、設定、Thawの設定を変更しない。

## 起動

```sh
./script/build_and_run.sh --desktop        # Releaseをビルド・パッケージして通常起動
./script/build_and_run.sh --probe-desktop  # 同じ版を20秒で自動終了する診断起動
```

生成物：`build/Variants/Masked Notch Desktop.app`。
Finderから開いても時間制限なしで起動する。メニューバーの表示は「背景」。
bundle IDは `local.MaskedNotch.Desktop` で、オン／オフやログイン時起動の設定は別。
試験中のログイン時起動は不要。開始時には既存のMasked Notch通常／A／B／Blink版へ
終了を要求する。旧版へ戻すときは、この試験版のメニューから先に「終了」する。

## 2026-09-08の検証

- Core 20件、Xcode 32件成功。Desktop配置の上下関係と、ロックパネルが
  Desktop配置に引きずられないことを追加検証した。
- Releaseビルド、アドホック署名のstrict検証成功。バージョン0.1.0、Build 5。
- 20:47:55〜20:48:15 JSTの診断起動で、visible=true、key=false、
  mouseIgnored=true、配置 `(0, 1131, 1800, 38)` ポイントを確認。
- 公開ウィンドウ一覧で、前からOSメニュー24、Thaw24、Dock20、
  Window Serverの上端パネル−2147483602、Finder−2147483603、
  **本アプリ−2147483622**、Dockのデスクトップ全面ウィンドウ−2147483624、
  Window Serverの全面ウィンドウ−2147483626の順を確認した。
- 診断期間にrefresh-tick／blinkの記録なし。20秒後に終了し、
  その後のウィンドウ一覧に本アプリの帯が残らないことを確認した。
- FinderへのComputer Useアクセスが承認されず、画面の目視確認はできなかった。
  **配置成功は、青へ戻らず黒を維持できることの証明ではない。**
  メニュー側が独自の背景を合成していれば、この配置でも黒が見えない可能性がある。
  ロック画面、Spaces切替時の見え方、クリック操作も未検証。

実測ログは `docs/evidence/desktop-layer-*.log`。
通常版へ採用した修正ではなく、表示結果を比較する試験版として扱う。
