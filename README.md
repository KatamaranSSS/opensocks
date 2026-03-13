# OpenSocks

Минимальный репозиторий для одного рабочего сервиса `Shadowsocks` без собственного клиента, панели и backend.

Цель простая:

1. поднять `ssserver` на VPS;
2. открыть `tcp+udp` на одном порту;
3. сгенерировать текстовый `ss://` конфиг;
4. отдать этот конфиг коллеге;
5. проверить, что его клиент реально ходит через VPS.

## Что осталось в проекте

- [PLAN.md](/Users/Katan/CodexProjects/ShadowSocks/PLAN.md) - рабочий план и текущий статус
- [PROJECT_INPUTS.md](/Users/Katan/CodexProjects/ShadowSocks/PROJECT_INPUTS.md) - зафиксированные параметры сервера и текущие решения
- [deploy/docker-compose.server.yml](/Users/Katan/CodexProjects/ShadowSocks/deploy/docker-compose.server.yml) - один контейнер `ssserver`
- [deploy/.env.server.example](/Users/Katan/CodexProjects/ShadowSocks/deploy/.env.server.example) - шаблон серверных переменных
- [scripts/deploy_remote.sh](/Users/Katan/CodexProjects/ShadowSocks/scripts/deploy_remote.sh) - удалённый деплой
- [scripts/print_ss_config.sh](/Users/Katan/CodexProjects/ShadowSocks/scripts/print_ss_config.sh) - печать готового `ss://` URI
- [scripts/deploy_ss2022_test.sh](/Users/Katan/CodexProjects/ShadowSocks/scripts/deploy_ss2022_test.sh) - отдельный тестовый deploy для SS2022
- [scripts/issue_ss2022_user.sh](/Users/Katan/CodexProjects/ShadowSocks/scripts/issue_ss2022_user.sh) - выдача пользователя SS2022 с персональным ключом
- [scripts/print_ss2022_config.sh](/Users/Katan/CodexProjects/ShadowSocks/scripts/print_ss2022_config.sh) - печать персонального `ss://` URI для SS2022
- [scripts/list_ss2022_users.sh](/Users/Katan/CodexProjects/ShadowSocks/scripts/list_ss2022_users.sh) - список пользователей SS2022
- [scripts/remove_ss2022_user.sh](/Users/Katan/CodexProjects/ShadowSocks/scripts/remove_ss2022_user.sh) - удаление пользователя SS2022
- [scripts/generate_ss2022_key.sh](/Users/Katan/CodexProjects/ShadowSocks/scripts/generate_ss2022_key.sh) - генерация валидного SS2022 ключа
- [scripts/deploy_multi_user.sh](/Users/Katan/CodexProjects/ShadowSocks/scripts/deploy_multi_user.sh) - реальный multi-user (уникальные порт+пароль на пользователя)
- [scripts/issue_multi_user.sh](/Users/Katan/CodexProjects/ShadowSocks/scripts/issue_multi_user.sh) - выдать нового пользователя multi-user
- [scripts/print_multi_user_config.sh](/Users/Katan/CodexProjects/ShadowSocks/scripts/print_multi_user_config.sh) - печать `ss://` конфига пользователя multi-user
- [scripts/list_multi_users.sh](/Users/Katan/CodexProjects/ShadowSocks/scripts/list_multi_users.sh) - список пользователей multi-user
- [scripts/remove_multi_user.sh](/Users/Katan/CodexProjects/ShadowSocks/scripts/remove_multi_user.sh) - удаление пользователя multi-user
- [scripts/remove_ss_user.sh](/Users/Katan/CodexProjects/ShadowSocks/scripts/remove_ss_user.sh) - удаление пользователя из реестра
- [scripts/generate_password.sh](/Users/Katan/CodexProjects/ShadowSocks/scripts/generate_password.sh) - генерация пароля

## Как это теперь работает

1. На сервере создаётся `deploy/.env.server`.
2. `scripts/deploy_remote.sh` генерирует `deploy/ssserver.json`.
3. Docker поднимает `shadowsocks-rust` в режиме `tcp_and_udp`.
4. Скрипт открывает `tcp/udp` порт в `ufw`, если он включён.
5. `scripts/print_ss_config.sh` печатает готовый `ss://` конфиг.

## Быстрый запуск

1. Сгенерировать пароль:

```bash
/Users/Katan/CodexProjects/ShadowSocks/scripts/generate_password.sh
```

2. Создать на сервере `/opt/opensocks/deploy/.env.server` по шаблону [deploy/.env.server.example](/Users/Katan/CodexProjects/ShadowSocks/deploy/.env.server.example).

3. Запустить деплой:

```bash
ssh -i ~/.ssh/opensocks_actions root@109.71.246.216 "DEPLOY_PATH=/opt/opensocks bash /opt/opensocks/scripts/deploy_remote.sh"
```

4. Получить конфиг:

```bash
/Users/Katan/CodexProjects/ShadowSocks/scripts/print_ss_config.sh sergei-spb-key
```

5. Выдать конфиг и записать пользователя в реестр:

```bash
/Users/Katan/CodexProjects/ShadowSocks/scripts/issue_ss_config.sh ilgam
```

6. Показать всех пользователей из реестра:

```bash
/Users/Katan/CodexProjects/ShadowSocks/scripts/list_ss_users.sh
```

7. Показать все `ss://` конфиги из реестра:

```bash
/Users/Katan/CodexProjects/ShadowSocks/scripts/list_ss_configs.sh
```

## Telegram bot (approval flow)

Сценарий:

1. коллега отправляет `/request` боту;
2. админ получает заявку с кнопками `Принять` и `Отклонить`;
3. после `Принять` админ отправляет логин;
4. бот запускает `issue_multi_user.sh`, применяет изменения через `deploy_multi_user.sh` и отправляет пользователю `ss://` конфиг.
5. один Telegram user может получить только один выданный конфиг; повторный `/request` блокируется.

Дополнительно для админа:

- `/newcfg` - ручной выпуск: бот просит логин и сразу выдает конфиг;
- `/configs` - inline-кнопки с логинами из `users-multi.txt`;
- тап по логину -> бот присылает конфиг в code block + кнопку `Удалить конфиг`;
- `Удалить конфиг` удаляет логин из `users-multi.txt`, применяет изменения и снимает лимит для привязанного Telegram user;
- `/cancel` - отмена текущего admin-flow.

Старый режим `1 пароль = 1 порт` не удален. Если нужен legacy-режим для старых процедур, переопредели пути скриптов в `bot/.env` на `issue_ss_config.sh` / `print_ss_config.sh` / `remove_ss_user.sh` / `list_ss_users.sh` и `users.txt`.

Файлы:

- [bot/config_bot.py](/Users/Katan/CodexProjects/ShadowSocks/bot/config_bot.py)
- [bot/.env.example](/Users/Katan/CodexProjects/ShadowSocks/bot/.env.example)
- [bot/opensocks-config-bot.service.example](/Users/Katan/CodexProjects/ShadowSocks/bot/opensocks-config-bot.service.example)

Быстрый запуск на сервере:

```bash
cd /opt/opensocks
python3 -m venv .venv
.venv/bin/pip install -r bot/requirements.txt
cp bot/.env.example bot/.env
```

Заполни в `bot/.env`:

- `TELEGRAM_BOT_TOKEN`
- `ADMIN_TELEGRAM_ID`
- `ISSUE_SCRIPT_PATH` (по умолчанию уже задан)
- `PRINT_SCRIPT_PATH` (по умолчанию уже задан)
- `REMOVE_SCRIPT_PATH` (по умолчанию уже задан)
- `LIST_USERS_SCRIPT_PATH` (по умолчанию уже задан)
- `APPLY_SCRIPT_PATH` (по умолчанию уже задан)
- `OPENSOCKS_USERS_FILE` (по умолчанию: `deploy/users-multi.txt`)

Подключи сервис:

```bash
cp bot/opensocks-config-bot.service.example /etc/systemd/system/opensocks-config-bot.service
systemctl daemon-reload
systemctl enable --now opensocks-config-bot
systemctl status opensocks-config-bot --no-pager
```

## Obfuscation test branch

Ветка `codex/obfuscation-test` добавляет переключаемую обфускацию через `v2ray-plugin`.

1. В `deploy/.env.server` выставить:

```bash
SSSERVER_OBFS_ENABLED=true
SSSERVER_PLUGIN=v2ray-plugin
SSSERVER_OBFS_MODE=websocket
SSSERVER_OBFS_PATH=/ws
SSSERVER_OBFS_HOST=
```

2. Запустить обычный деплой:

```bash
ssh -i ~/.ssh/opensocks_actions root@109.71.246.216 "DEPLOY_PATH=/opt/opensocks bash /opt/opensocks/scripts/deploy_remote.sh"
```

3. Сгенерировать obfs-конфиг:

```bash
/Users/Katan/CodexProjects/ShadowSocks/scripts/print_ss_config.sh sergei-obfs
```

4. Для отката:

```bash
SSSERVER_OBFS_ENABLED=false
```

## Isolated SS2022 test (does not touch main 8389)

Этот контур поднимается отдельным контейнером и отдельным портом, чтобы не ломать рабочий `chacha20-ietf-poly1305` на `8389`.
Он настроен как `1 порт + много паролей` через `users` в SS2022.

1. В `deploy/.env.server` добавь/проверь переменные:

```bash
SS2022_PUBLIC_HOST=109.71.246.216
SS2022_PORT=8391
SS2022_MODE=tcp_and_udp
SS2022_METHOD=2022-blake3-aes-128-gcm
SS2022_PASSWORD_BASE64=<вывод scripts/generate_ss2022_key.sh>
SS2022_TIMEOUT=60
SS2022_USERS_FILE=deploy/users-ss2022.txt
```

2. Сгенерируй ключ:

```bash
/Users/Katan/CodexProjects/ShadowSocks/scripts/generate_ss2022_key.sh
```

3. Подними только тестовый SS2022:

```bash
ssh -i ~/.ssh/opensocks_actions root@109.71.246.216 "DEPLOY_PATH=/opt/opensocks bash /opt/opensocks/scripts/deploy_ss2022_test.sh"
```

4. Получи тестовый конфиг:

```bash
/Users/Katan/CodexProjects/ShadowSocks/scripts/issue_ss2022_user.sh happ-ss2022-test
```

5. Применить изменения users на сервере (после добавления/удаления пользователя):

```bash
ssh -i ~/.ssh/opensocks_actions root@109.71.246.216 "DEPLOY_PATH=/opt/opensocks bash /opt/opensocks/scripts/deploy_ss2022_test.sh"
```

## Real Multi-user (recommended for production)

Этот режим работает как "реальный multi-user": у каждого пользователя свой порт и свой пароль.

1. Добавь в `deploy/.env.server`:

```bash
SS_MULTI_PUBLIC_HOST=109.71.246.216
SS_MULTI_IMAGE=ghcr.io/shadowsocks/ssserver-rust:latest
SS_MULTI_MODE=tcp_and_udp
SS_MULTI_DEFAULT_METHOD=chacha20-ietf-poly1305
SS_MULTI_TIMEOUT=60
SS_MULTI_USERS_FILE=deploy/users-multi.txt
SS_MULTI_PORT_MIN=20000
SS_MULTI_PORT_MAX=29999
```

2. Выдай пользователя (создаст уникальный порт+пароль и вернет `ss://`):

```bash
/Users/Katan/CodexProjects/ShadowSocks/scripts/issue_multi_user.sh ilgam
```

3. Применить изменения на сервере:

```bash
ssh -i ~/.ssh/opensocks_actions root@109.71.246.216 "DEPLOY_PATH=/opt/opensocks bash /opt/opensocks/scripts/deploy_multi_user.sh"
```

4. Показать пользователей и их порты:

```bash
/Users/Katan/CodexProjects/ShadowSocks/scripts/list_multi_users.sh
```

5. Удалить пользователя (после удаления снова запусти deploy из шага 3):

```bash
/Users/Katan/CodexProjects/ShadowSocks/scripts/remove_multi_user.sh ilgam
```

## Что считается рабочим результатом

1. Клиент импортирует `ss://` конфиг без ручного редактирования.
2. После `Connect` открывается `https://api.ipify.org`.
3. IP в браузере клиента равен IP VPS.
