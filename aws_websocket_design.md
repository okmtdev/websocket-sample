# AWSサーバーレスWebSocketチャットの設計例

---

## Lambda関数の構成

| 関数名                | トリガーイベント      | 主な役割                                      |
|----------------------|----------------------|-----------------------------------------------|
| connectHandler       | $connect             | 接続時のConnectionId保存                      |
| disconnectHandler    | $disconnect          | 切断時のConnectionId削除                      |
| messageHandler       | sendMessage（独自）  | メッセージ保存・全クライアントへの配信         |
| getHistoryHandler    | getHistory（独自）   | チャット履歴の取得（必要に応じて）             |

---

## DynamoDBテーブル設計

### 1. 接続情報テーブル（Connections）

| 属性名         | 型      | 説明                         |
|---------------|--------|------------------------------|
| connectionId  | String | パーティションキー。API Gatewayの接続ID |
| userName      | String | ユーザー名（任意）            |
| connectedAt   | Number | 接続時刻（UNIXタイムスタンプ） |

**主キー:** connectionId

---

### 2. チャットメッセージテーブル（ChatMessages）

| 属性名         | 型      | 説明                         |
|---------------|--------|------------------------------|
| roomId        | String | パーティションキー。ルームID（単一ルームなら"main"等） |
| timestamp     | Number | ソートキー。メッセージ送信時刻（UNIXタイムスタンプ） |
| messageId     | String | メッセージID（UUID等）        |
| userName      | String | 送信者名                      |
| message       | String | メッセージ本文                |

**主キー:** roomId（パーティションキー） + timestamp（ソートキー）

---

## 保存するデータ例

### Connectionsテーブル

| connectionId         | userName | connectedAt   |
|----------------------|----------|--------------|
| abc123               | Alice    | 1718700000   |
| def456               | Bob      | 1718700010   |

### ChatMessagesテーブル

| roomId | timestamp   | messageId | userName | message         |
|--------|-------------|-----------|----------|-----------------|
| main   | 1718700020  | uuid-1    | Alice    | こんにちは！     |
| main   | 1718700030  | uuid-2    | Bob      | こんばんは！     |

---

## Lambda関数の役割詳細

- **connectHandler**  
  - event.requestContext.connectionIdをConnectionsテーブルに保存
  - 必要に応じてuserNameも保存（初回メッセージ時に上書きでも可）

- **disconnectHandler**  
  - event.requestContext.connectionIdをConnectionsテーブルから削除

- **messageHandler**  
  - event.bodyからuserName, message等を取得
  - ChatMessagesテーブルに新規メッセージを保存
  - Connectionsテーブルから全connectionIdを取得し、API Gateway管理APIで全クライアントにメッセージを送信

- **getHistoryHandler**（任意）  
  - ChatMessagesテーブルから最新N件を取得し、リクエスト元クライアントに返却

---

## 備考

- メッセージ保存時はroomIdでチャットルームを分けることも可能
- メッセージ取得はtimestampで範囲検索・ページングが容易
- ConnectionsテーブルはAPI Gatewayの接続IDで管理するのがシンプル
