# Big Break Mobile

Flutter приложение Big Break.

Главные документы перед работой:
- `../docs/design-system-big-break.md`
- `../docs/flutter-ui-mapping-big-break.md`
- `../docs/flutter-engineering-standards.md`

## Install

Нужно поставить:
- Xcode из App Store
- Flutter SDK
- CocoaPods

Проверка окружения:

```bash
flutter doctor
```

Подготовка проекта:

```bash
cd mobile
flutter pub get
cd ios
pod install
cd ..
```

## Запуск через Flutter

```bash
cd mobile
flutter run
```

По умолчанию приложение смотрит на тестовый backend:
- API: `https://api.frendly.tech`
- WebSocket: `wss://api.frendly.tech/ws`
- Telegram bot: `frendly_code_bot`

Если нужен другой backend:

```bash
flutter run \
  --dart-define=BIG_BREAK_MAPKIT_API_KEY=your-mapkit-key \
  --dart-define=BIG_BREAK_API_URL=https://your-api-host \
  --dart-define=BIG_BREAK_CHAT_WS_URL=wss://your-api-host/ws \
  --dart-define=BIG_BREAK_TELEGRAM_BOT_USERNAME=your_bot
```

Android берет MapKit ключ из `BIG_BREAK_MAPKIT_API_KEY`.
Можно передать его через `--dart-define`, переменную окружения или Gradle property.
Реальный ключ не коммить.

## Сборка руками в Xcode

1. Выполни подготовку из блока `Install`.
2. Открой workspace, не project:

```bash
open mobile/ios/Runner.xcworkspace
```

3. В Xcode выбери scheme `Runner`.
4. Выбери устройство или симулятор.
5. Открой `Runner` -> `Signing & Capabilities`.
6. Выбери свой `Team`.
7. Если Xcode попросит, поменяй `Bundle Identifier` на уникальный.
8. Нажми `Product` -> `Build`.
9. Для запуска нажми `Product` -> `Run`.

Если Pods не подтянулись или Xcode ругается на зависимости:

```bash
cd mobile
flutter clean
flutter pub get
cd ios
pod install
cd ..
```

Важно: открывать нужно `Runner.xcworkspace`. Если открыть `Runner.xcodeproj`, Pods могут не собраться.
