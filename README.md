# Sleep Toggle

MacBook のフタを閉じてもスリープしない状態（クラムシェル運用）を、
Dock にもメニューバーにも常駐せずに切り替えるための小さなツール。

実体は `sudo pmset -a disablesleep 0|1` の切り替えです。

## ⚠️ 先に知っておくこと

**この設定は再起動をまたいで残ります。**

```
/Library/Preferences/com.apple.PowerManagement.plist
  "SystemPowerSettings" => { "SleepDisabled" => true }
```

root 所有の plist に書き込まれるため、ON のまま放置すると Mac は二度とスリープしません。
ON のままバッテリー駆動でカバンに入れると本体が発熱し続けます。
`scripts/sleeptoggle` はバッテリー駆動中に ON にした場合に警告を出しますが、
最終的な安全弁は**状態が常に見えていること**です。

現在の状態はいつでも root なしで読めます:

```bash
pmset -g | grep SleepDisabled     # 0 = 通常 / 1 = スリープ無効
```

## Phase 1 — Shortcuts 版（Phase 2 を使うなら不要）

常駐アイコンが一切出ない最小構成。ホットキーと Spotlight から叩けます。

### 1. パスワード免除を入れる

`pmset -a disablesleep` は root を要求します。毎回パスワードを打たずに済むよう、
**この 2 つの呼び出しだけ**に限定したドロップインを入れます。

```bash
sudo ./scripts/install-sudoers.sh
```

sudoers は Cmnd に引数が書かれている場合に引数の完全一致を要求するため、
ワイルドカードのない `sudoers.d/sleeptoggle` では
`pmset -a disablesleep 0` と `pmset -a disablesleep 1` 以外は一切通りません。
インストーラは `visudo -cqf` で構文検証してから設置するので、
sudo が壊れて締め出される事故は起きません。

取り消しは `sudo rm /etc/sudoers.d/sleeptoggle` です。

### 2. 動作確認

```bash
./scripts/sleeptoggle status
./scripts/sleeptoggle          # 反転
```

### 3. Shortcuts に登録してホットキーを割り当てる

1. Shortcuts.app で新規ショートカット（名前は `Sleep Toggle` など）
2. **Run Shell Script** アクションを 1 つ置き、Shell を `/bin/bash` にして中身を:
   ```
   <クローン先>/scripts/sleeptoggle
   ```
3. 右パネルの ⓘ → **Add Keyboard Shortcut** で好きなキーを割り当て

これで Dock にもメニューバーにも何も出ません。Spotlight からも名前で呼べます。

## Phase 2 — Control Center 版

macOS 26.0 でサードパーティの Control Center コントロールが解禁されました。

```
ControlWidgetToggle → @available(iOS 18.0, macOS 26.0, watchOS 26.0, *)
```

### 構成

Control Center のコントロールは **App Sandbox 必須の appex** なので、
`pmset` を exec することも root になることも原理的にできません。橋渡しが要ります。

```
SleepToggle.app
├── Contents/MacOS/SleepToggle           ホスト App（LSUIElement / 常駐しない）
├── Contents/MacOS/SleepToggleHelper     root デーモン。ここだけが pmset を実行
├── Contents/MacOS/SleepToggleWatcher    フタ監視エージェント（音を鳴らす）
├── Contents/PlugIns/
│   └── SleepToggleControl.appex         Control Center コントロール
├── Contents/Library/LaunchDaemons/      SMAppService.daemon() で登録
└── Contents/Library/LaunchAgents/       SMAppService.agent() で登録
```

- コントロールは `SetValueIntent` なので、**Shortcuts と Spotlight からも同じ動作**が呼べます
- 音はユーザーセッションでしか鳴らせないため、フタ監視は**デーモンではなくエージェント**です
- 状態の読み取りも appex からはヘルパ経由です（サンドボックス下で `pmset` を叩けないため）

### ビルドと設置

```bash
brew install xcodegen    # 初回のみ
./scripts/build.sh       # xcodegen generate → xcodebuild → Developer ID で署名
./scripts/install.sh     # /Applications へ設置
```

`SleepToggle.xcodeproj` は `project.yml` からの生成物なので commit していません。

**`swiftc` で直接組み立ててはいけません。** WidgetKit の拡張は AppIntents の
メタデータ抽出を必要とし、これは Xcode のビルドフェーズでしか生成されません。

```
Contents/PlugIns/SleepToggleControl.appex/Contents/Resources/Metadata.appintents/
```

これが無いと chronod の `getAllDescriptors` が
`Error 4099 "The connection to service with pid -1 ... was invalidated"` で失敗し続け、
**Control Center にもウィジェットギャラリーにも一切出てきません**。
拡張プロセスは spawn 直後に死ぬため `ps` では捕捉できず、クラッシュレポートも残りません。
`pluginkit` には正常に登録されて見えるので、そこからは異常に気付けません。

`SMAppService` はデーモン登録時に App のパスを記録するため、
`build/` から直接登録すると再ビルドで壊れます。必ず設置してから登録してください。

アイコンを作り直すときは `./scripts/make-icon.sh`、
警告音は `python3 scripts/make-chime.py Resources/LidWarning.wav`、
月＋斜線のシンボルは
`swift scripts/make-symbol.swift Resources/Symbols.xcassets/moon.slash.symbolset/moon.slash.svg` です。
SF Symbols に `moon.slash` 系が無いため自作しています。**Control Center は SF Symbol か
カスタムシンボル（`.symbolset`）しか描かず、普通の画像アセットを渡すと「?」になります。**

### 配布

```bash
./scripts/notarize.sh    # 公証して staple する
```

初回だけ資格情報の保存が要ります。詳しくはスクリプト先頭のコメントを参照してください。

### 初回セットアップ

1. `/Applications/SleepToggle.app` を開く
2. macOS が「バックグラウンド項目」の許可を求めたら許可する
   （特権ヘルパと警告音の監視は App が起動時に自動で登録します）
3. Control Center の編集からコントロール「スリープしない」を追加する

以後は Control Center だけで操作でき、App を開く必要はありません。
**appex は App を一度起動しないと登録されません**（`lsregister -f` だけでは不足）。

### 更新の効き方

- 特権ヘルパは接続が途絶えて 20 秒で自分で終了し、次の接続で設置済みの最新版が起動します
- 警告音の監視は常駐するため、版が変わった最初の App 起動で自動的に入れ替えます


Phase 2 を使うなら Phase 1 の sudoers ドロップインは不要です:

```bash
sudo rm /etc/sudoers.d/sleeptoggle
```

## ファイル

| パス | 役割 |
| --- | --- |
| `scripts/sleeptoggle` | トグル本体。`toggle` / `on` / `off` / `status` |
| `scripts/install-sudoers.sh` | sudoers ドロップインの検証付きインストーラ |
| `sudoers.d/sleeptoggle` | 許可する pmset 呼び出しの定義（`@USER@` は置換される） |
| `Sources/Shared/` | XPC プロトコル、pmset ラッパ、XPC クライアント |
| `Sources/Helper/` | root デーモン。`--status` / `--set` の診断つき |
| `Sources/Watcher/` | フタ監視エージェント。`--status` / `--test-sound` の診断つき |
| `Sources/Control/` | Control Center コントロールの appex |
| `Sources/App/` | ホスト App |
| `project.yml` | xcodegen のプロジェクト定義（`.xcodeproj` は生成物） |
| `scripts/build.sh` | xcodegen + xcodebuild でのビルドと署名 |
| `scripts/notarize.sh` | 公証と staple |
| `scripts/make-icon.sh` | App アイコンの再生成 |
| `scripts/make-symbol.swift` | 月＋斜線シンボル（App と Control Center で共有）の再生成 |
| `Resources/Symbols.xcassets` | 共有シンボル |

## ライセンス

MIT License。詳しくは [LICENSE](LICENSE) を参照してください。
