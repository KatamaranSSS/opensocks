# OpenSocks macOS

Первый нативный `macOS`-клиент на `SwiftUI`.

## Что уже умеет

- хранить `client token` в Keychain
- хранить `API base URL` в `UserDefaults`
- хранить путь до локального `sslocal`
- хранить локальный `SOCKS5` порт
- запрашивать `GET /api/v1/client/bootstrap`
- показывать активные `ss://` конфиги пользователя
- копировать `ss://` ссылку и пароль в буфер обмена
- запускать и останавливать локальный `sslocal`

## Как тестировать на текущем сервере

Сначала подними SSH-туннель:

```bash
ssh -i ~/.ssh/opensocks_actions -L 18000:127.0.0.1:18000 root@109.71.246.216
```

Потом в приложении используй:

- `API base URL`: `http://127.0.0.1:18000`
- `Client token`: токен пользователя из backend

## Как собрать

```bash
cd macos/OpenSocksMac
swift build
swift run OpenSocksMacApp
```

Если `swift build` падает с ошибкой про несовместимые `Xcode` / `Command Line Tools`,
нужно выровнять локальную Apple toolchain.

## Что нужно для `Connect / Disconnect`

На Mac должен быть установлен `sslocal`.

Обычно:

```bash
brew install shadowsocks-rust
which sslocal
```

Потом в приложении:

- `sslocal binary path`: путь из `which sslocal`
- `Local SOCKS5 port`: например `1086`
