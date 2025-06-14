## 説明 (Explanation)
RSG Any%のWRペースを通知する**Android**アプリです。  
An **Android** application that notifies the WR pace of RSG Any%.  

加えて、現在のペースを[PaceMan](https://paceman.gg/)風に表示します。  
and, the current pace is displayed in a [PaceMan](https://paceman.gg/) style.

## 使い方 (How to use)
1. [最新のリリース](https://github.com/mebuki117/PaceAlert/releases/latest)から、`pace-alert_vx.x.x.apk`をスマホでダウンロード  
   From the [latest release](https://github.com/mebuki117/PaceAlert/releases/latest), download `pace-alert_vx.x.x.apk` with your phone
2. ダウンロードしたファイルを開いて、アプリをインストール  
   Open the downloaded file and install the app
3. システムの設定を開き、アプリの通知をオンにする（Android 14では、オフがデフォルトのようです）  
   Open the system settings and turn on the app notification
4. アプリを起動  
   Start the app

起動後はアプリが常駐されます。これにより、いつでも通知を受け取ることができます。  
After startup, the app will be resident. This allows you to receive notifications at any time.
 
## 通知対象 (Notification Pace)
以下に一致する場合、音ありで通知されます。  
If you match the following, you will be notified with a sound.  
- sub 5:20 Stronghold
- sub 5:55 Enter End
- sub 6:50.359 Finish (sub lowkey)

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

## クレジット (Credit)
- アイデア (Idea)：[まさ (masa)](https://x.com/masa_ERC/status/1846322439976112189)

## スクリーンショット (Screenshots)
<img src="https://github.com/user-attachments/assets/cf289896-4ccc-40bb-8574-632c6db0c001" width="25%" />
<img src="https://github.com/user-attachments/assets/1871d25f-09c5-439c-917b-adb0f98ef1a2" width="25%" />
<img src="https://github.com/user-attachments/assets/759d6d4c-7645-48e0-9dfb-ef1c159ff837" width="25%" />

## 開発環境
- Android 11.0 (API 30)
- Android 14.0 (API 34)
