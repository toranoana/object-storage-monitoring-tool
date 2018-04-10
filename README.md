## RubyでConoHaオブジェクトストレージの使用率を監視

### 概要
ConoHaが提供しているAPIでディスクの使用率を取得し、Slackに通知します。  
使用率が80% 以上に達した時は、メンション付きで通知します。   

※ ConoHa のAPIドキュメントは、以下にて公開されています  
https://www.conoha.jp/docs/  

### 予め必要な情報
- ConoHa APIのユーザー名
- ConoHa APIのユーザパスワード
- ConoHa APIのテナントID
- 通知するSlack

### 実行コマンド
```
ruby tool/monitoring_conoha.rb
```
