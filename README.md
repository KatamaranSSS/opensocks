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

## Что считается рабочим результатом

1. Клиент импортирует `ss://` конфиг без ручного редактирования.
2. После `Connect` открывается `https://api.ipify.org`.
3. IP в браузере клиента равен IP VPS.
