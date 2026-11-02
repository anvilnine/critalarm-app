# Crit Alarm translation glossary

Fixed words for every translation of the app, the site and the store listings. Drafted by Codex,
reviewed by agy (Gemini 3.8 Flash), picked by Claude on 2026-10-19. Translations are AI-generated.
Change a word here first, then in every file that uses it.

## German (de)
Register: informal du in explanatory text. Fixed button labels identical wherever quoted.

| English | de | keep EN | note |
|---|---|---|---|
| Crit | Crit | yes | mascot name |
| Crit Alarm | Crit Alarm | yes | product name |
| alarm | Alarm | no | not Anruf or Weckruf |
| ring / ringing | klingeln / klingelt | no | as a Wecker klingelt; avoid anrufen, Anruf |
| topic | Topic (pl. Topics) | yes | avoid Thema, Kanal |
| message | Nachricht | no | |
| incident | Vorfall | no | |
| Critical | Kritisch (screen: KRITISCH) | no | |
| Critical delivery | Kritische Zustellung | no | topic switch |
| priority | Priorität | no | Priorität 1 to 5 |
| I'm up | Ich bin wach | no | stops ringing, starts desk timer |
| At my desk | Am Schreibtisch | no | closes the alarm; short for a big button |
| Silence | Stummschalten | no | stops sound, alarm stays open |
| acknowledge(d) | bestätigen / bestätigt | no | |
| desk timer | Schreibtisch-Timer | no | |
| Will it wake me? | Weckt es mich? | no | question, never a guarantee |
| test alarm | Testalarm | no | |
| Cloud | Cloud | yes | subscription name |
| Pro | Pro | yes | one-time pack |
| Free | Kostenlos | no | plan name and "free of charge" |
| self-hosted | selbstgehostet | no | one word |
| server | Server | yes | |
| relay | Relay | yes | not Relais |
| token | Token | yes | |
| push | Push | yes | |
| widget | Widget | yes | |
| wake-up challenge | Aufwachaufgabe | no | task before At my desk closes |
| Personalize | Personalisieren | no | |
| Look | Aussehen | no | |
| Sound | Ton | no | never Klingelton |
| alarm sound | Alarmton | no | |
| plan | Tarif | no | |
| subscription | Abo | no | not for Pro |
| one-time purchase | Einmalkauf | no | |
| notification | Benachrichtigung | no | |
| history | Alarmverlauf | no | one word everywhere |
| device | Gerät | no | |
| phone | Handy | no | |
| account | Konto | no | |
| check | Prüfung / prüfen | no | |
| delivery | Zustellung | no | |
| weekly delivery check | Wöchentliche Zustellprüfung | no | |
| app icon | App-Symbol | no | |
| purchase | Kauf | no | |
| default | Standard | no | |
| Settings | Einstellungen | no | |

## Japanese (ja)
Register: neutral です・ます in sentences, short labels for controls, first-person declarations for the two acknowledge buttons. Katakana with long vowels: サーバー, タイマー, トピック, トークン, プッシュ, ウィジェット. Product and plan names in Latin letters.

| English | ja | keep EN | note |
|---|---|---|---|
| Crit | Crit | yes | |
| Crit Alarm | Crit Alarm | yes | |
| alarm | アラーム | no | not 電話, 着信, 呼び出し |
| ring / ringing | 鳴る / 鳴動中 | no | never 着信中 |
| topic | トピック | no | |
| message | メッセージ | no | |
| incident | インシデント | no | |
| Critical | 重大 | no | same on alarm screen and switch |
| Critical delivery | 重大アラームの配信 | no | |
| priority | 優先度 | no | 優先度1 to 5 |
| I'm up | 起きました | no | |
| At my desk | デスクに着きました | no | |
| Silence | 消音 | no | |
| acknowledge(d) | 確認する / 確認済み | no | not 解決済み |
| desk timer | デスク到着タイマー | no | |
| Will it wake me? | 起こしてくれる？ | no | |
| test alarm | テストアラーム | no | |
| Cloud | Cloud | yes | |
| Pro | Pro | yes | |
| Free | 無料 | no | plan name and "free of charge" |
| self-hosted | セルフホスト | no | |
| server | サーバー | no | |
| relay | リレー | no | |
| token | トークン | no | |
| push | プッシュ | no | |
| widget | ウィジェット | no | |
| wake-up challenge | 起床タスク | no | avoids 確認, which means acknowledge |
| Personalize | カスタマイズ | no | |
| Look | 見た目 | no | |
| Sound | サウンド | no | never 着信音 |
| alarm sound | アラーム音 | no | |
| plan | プラン | no | |
| subscription | サブスクリプション | no | not for Pro |
| one-time purchase | 買い切り | no | |
| notification | 通知 | no | |
| history | アラーム履歴 | no | one word everywhere |
| device | デバイス | no | |
| phone | スマホ / スマートフォン | no | スマホ in short labels, スマートフォン in sentences |
| account | アカウント | no | |
| check | チェック | no | keeps it apart from 確認 (acknowledge) |
| delivery | 配信 | no | |
| weekly delivery check | 毎週の配信チェック | no | |
| app icon | アプリアイコン | no | |
| purchase | 購入 | no | |
| default | デフォルト | no | |
| Settings | 設定 | no | |

## Do not translate
Crit, Crit Alarm, Crit Alarm Cloud, Cloud, Pro. Placeholders ({}, {topic}, {count}...), URLs, commands, user topic names, JSON keys.

## Decided doubts

1. de ring: klingeln (an alarm clock klingelt).
2. de desk timer: Schreibtisch-Timer.
3. ja Critical: 重大 (standard in incident tooling; 緊急 reads as civil alarm).
4. ja Will it wake me?: 起こしてくれる？
5. ja wake-up challenge: 起床タスク.
6. ja Critical delivery stays 重大アラームの配信. agy proposed 重大配信; it reads unnatural.
