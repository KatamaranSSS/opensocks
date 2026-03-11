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
4. бот запускает `issue_ss_config.sh` и отправляет пользователю `ss://` конфиг.

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

## Что считается рабочим результатом

1. Клиент импортирует `ss://` конфиг без ручного редактирования.
2. После `Connect` открывается `https://api.ipify.org`.
3. IP в браузере клиента равен IP VPS.
