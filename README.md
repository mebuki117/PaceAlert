## 説明
RSG Any%のWRペースを通知する**Android**アプリです。  
加えて、現在のペースを[PaceMan](https://paceman.gg/)風に表示します。

## 使い方
1. [最新のリリース](https://github.com/mebuki117/PaceAlert/releases/latest)から、`pace-alert_vx.x.x.apk`をスマホでダウンロード
2. ダウンロードしたファイルを開いて、アプリをインストール
3. システムの設定を開き、アプリの通知をオンにする（Android 14では、オフがデフォルトのようです）
4. アプリを起動

起動後はアプリが常駐されます。これにより、いつでも通知を受け取ることができます。

## 通知対象
以下に一致する場合、音ありで通知されます。
- sub 5:30 Stronghold
- sub 6:11 Enter End
- sub 7:01.494 Finish (sub drip)

## 機能
### Current Pace
現在のペースが一覧として表示されます。

### Stats
[PaceManのStats](https://paceman.gg/stats/)を表示します。

#### Leaderboard
ランキングです。  
ユーザー名のタップで、ユーザーのStatsがブラウザで開かれます。

#### Search
ユーザーの統計を検索できます。

### Settings
設定ですが、現状機能はありません。

## 備考
- アプリのライト/ダークモードは、システムのモードに依存します
- 20秒に一度、PaceMan APIから情報を取得します
- 通知音は手動で停止しない場合、1分後に自動停止されます
- アプリ内から新バージョンをダウンロードする場合、ブラウザのダウンロード設定によっては、ダウンロードされないことがあります

## クレジット
- アイデア：[まさ](https://x.com/masa_ERC/status/1846322439976112189)

## スクリーンショット
<img src="https://github.com/user-attachments/assets/cf289896-4ccc-40bb-8574-632c6db0c001" width="25%" />
<img src="https://github.com/user-attachments/assets/1871d25f-09c5-439c-917b-adb0f98ef1a2" width="25%" />
<img src="https://github.com/user-attachments/assets/759d6d4c-7645-48e0-9dfb-ef1c159ff837" width="25%" />

## 開発環境
- Android 11.0 (API 30)
- Android 14.0 (API 34)
