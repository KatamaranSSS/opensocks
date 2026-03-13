#!/usr/bin/env python3
from __future__ import annotations

import asyncio
import json
import os
import re
import secrets
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.constants import ParseMode
from telegram.ext import (
    Application,
    CallbackQueryHandler,
    CommandHandler,
    ContextTypes,
    MessageHandler,
    filters,
)

USERNAME_RE = re.compile(r"^[a-zA-Z0-9._-]+$")


@dataclass(frozen=True)
class Settings:
    bot_token: str
    admin_telegram_id: int
    issue_script: str
    print_script: str
    remove_script: str
    users_script: str
    apply_script: str
    env_file: str
    users_file: str
    state_file: str

    @staticmethod
    def from_env() -> "Settings":
        token = os.getenv("TELEGRAM_BOT_TOKEN", "").strip()
        admin_id_raw = os.getenv("ADMIN_TELEGRAM_ID", "").strip()
        if not token:
            raise RuntimeError("TELEGRAM_BOT_TOKEN is required")
        if not admin_id_raw:
            raise RuntimeError("ADMIN_TELEGRAM_ID is required")

        try:
            admin_id = int(admin_id_raw)
        except ValueError as exc:
            raise RuntimeError("ADMIN_TELEGRAM_ID must be integer") from exc

        return Settings(
            bot_token=token,
            admin_telegram_id=admin_id,
            issue_script=os.getenv(
                "ISSUE_SCRIPT_PATH", "/opt/opensocks/scripts/issue_multi_user.sh"
            ),
            print_script=os.getenv(
                "PRINT_SCRIPT_PATH", "/opt/opensocks/scripts/print_multi_user_config.sh"
            ),
            remove_script=os.getenv(
                "REMOVE_SCRIPT_PATH", "/opt/opensocks/scripts/remove_multi_user.sh"
            ),
            users_script=os.getenv(
                "LIST_USERS_SCRIPT_PATH", "/opt/opensocks/scripts/list_multi_users.sh"
            ),
            apply_script=os.getenv(
                "APPLY_SCRIPT_PATH", "/opt/opensocks/scripts/deploy_multi_user.sh"
            ),
            env_file=os.getenv("OPENSOCKS_ENV_FILE", "/opt/opensocks/deploy/.env.server"),
            users_file=os.getenv(
                "OPENSOCKS_USERS_FILE", "/opt/opensocks/deploy/users-multi.txt"
            ),
            state_file=os.getenv("BOT_STATE_FILE", "/opt/opensocks/deploy/bot_state.json"),
        )


class StateStore:
    def __init__(self, path: str) -> None:
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.lock = asyncio.Lock()
        self.data: dict[str, Any] = {
            "requests": {},
            "active_by_user": {},
            "awaiting_admin_action": {},
            "issued_login_by_user": {},
        }

    async def load(self) -> None:
        async with self.lock:
            if self.path.exists():
                raw = self.path.read_text(encoding="utf-8")
                if raw.strip():
                    self.data = json.loads(raw)

            self.data.setdefault("requests", {})
            self.data.setdefault("active_by_user", {})
            self.data.setdefault("awaiting_admin_action", {})
            self.data.setdefault("issued_login_by_user", {})

            # migration from older key
            legacy = self.data.pop("awaiting_login_by_admin", {})
            if isinstance(legacy, dict):
                for admin_id, req_id in legacy.items():
                    self.data["awaiting_admin_action"][str(admin_id)] = {
                        "type": "approve_request",
                        "request_id": str(req_id),
                    }

            await self._save_locked()

    async def _save_locked(self) -> None:
        self.path.write_text(
            json.dumps(self.data, ensure_ascii=False, indent=2, sort_keys=True),
            encoding="utf-8",
        )

    async def save(self) -> None:
        async with self.lock:
            await self._save_locked()

    async def has_active_request(self, user_id: int) -> bool:
        async with self.lock:
            return str(user_id) in self.data["active_by_user"]

    async def get_issued_login(self, user_id: int) -> str | None:
        async with self.lock:
            return self.data["issued_login_by_user"].get(str(user_id))

    async def set_issued_login(self, user_id: int, login: str) -> None:
        async with self.lock:
            self.data["issued_login_by_user"][str(user_id)] = login
            await self._save_locked()

    async def remove_issued_by_login(self, login: str) -> list[int]:
        async with self.lock:
            removed: list[int] = []
            for user_id, assigned_login in list(self.data["issued_login_by_user"].items()):
                if assigned_login == login:
                    removed.append(int(user_id))
                    del self.data["issued_login_by_user"][user_id]
            await self._save_locked()
            return removed

    async def create_request(
        self, user_id: int, username: str | None, full_name: str, chat_id: int
    ) -> str:
        async with self.lock:
            req_id = secrets.token_hex(6)
            request = {
                "id": req_id,
                "status": "pending",
                "user_id": user_id,
                "chat_id": chat_id,
                "username": username or "",
                "full_name": full_name,
                "requested_at": datetime.now(timezone.utc).isoformat(),
            }
            self.data["requests"][req_id] = request
            self.data["active_by_user"][str(user_id)] = req_id
            await self._save_locked()
            return req_id

    async def get_request(self, req_id: str) -> dict[str, Any] | None:
        async with self.lock:
            request = self.data["requests"].get(req_id)
            return dict(request) if request else None

    async def set_status(self, req_id: str, status: str) -> dict[str, Any] | None:
        async with self.lock:
            request = self.data["requests"].get(req_id)
            if not request:
                return None
            request["status"] = status
            self.data["requests"][req_id] = request
            await self._save_locked()
            return dict(request)

    async def clear_user_active(self, user_id: int) -> None:
        async with self.lock:
            self.data["active_by_user"].pop(str(user_id), None)
            await self._save_locked()

    async def set_admin_action(self, admin_id: int, action: dict[str, str]) -> None:
        async with self.lock:
            self.data["awaiting_admin_action"][str(admin_id)] = action
            await self._save_locked()

    async def pop_admin_action(self, admin_id: int) -> dict[str, str] | None:
        async with self.lock:
            value = self.data["awaiting_admin_action"].pop(str(admin_id), None)
            await self._save_locked()
            return value


async def run_script(*cmd: str) -> tuple[int, str, str]:
    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    out, err = await proc.communicate()
    return proc.returncode, out.decode("utf-8", errors="replace"), err.decode(
        "utf-8", errors="replace"
    )


def is_admin(update: Update, settings: Settings) -> bool:
    user = update.effective_user
    return bool(user and user.id == settings.admin_telegram_id)


def request_keyboard(req_id: str) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(
        [
            [
                InlineKeyboardButton(
                    text="✅ Принять", callback_data=f"approve:{req_id}"
                ),
                InlineKeyboardButton(
                    text="❌ Отклонить", callback_data=f"reject:{req_id}"
                ),
            ]
        ]
    )


def users_keyboard(users: list[str]) -> InlineKeyboardMarkup:
    rows: list[list[InlineKeyboardButton]] = []
    for name in users:
        rows.append([InlineKeyboardButton(text=name, callback_data=f"cfgshow:{name}")])
    return InlineKeyboardMarkup(rows)


def delete_keyboard(username: str) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(
        [
            [
                InlineKeyboardButton(
                    text="🗑 Удалить конфиг", callback_data=f"cfgdel:{username}"
                )
            ]
        ]
    )


def _extract_config(stdout: str) -> str:
    lines = [line.strip() for line in stdout.splitlines() if line.strip()]
    return lines[-1] if lines else ""


def _extract_usernames(stdout: str) -> list[str]:
    names: list[str] = []
    seen: set[str] = set()

    for raw in stdout.splitlines():
        line = raw.strip()
        if not line:
            continue
        # Supports both plain "username" and tab-separated "username\tport\tmethod".
        username = line.split()[0]
        if USERNAME_RE.match(username) and username not in seen:
            seen.add(username)
            names.append(username)
    return names


async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    settings: Settings = context.application.bot_data["settings"]
    if is_admin(update, settings):
        text = (
            "Админ-режим.\n"
            "Команды:\n"
            "/newcfg - создать конфиг вручную\n"
            "/users - список пользователей\n"
            "/configs - inline список конфигов\n"
            "/cancel - отменить текущее ожидание"
        )
    else:
        text = (
            "Нажмите /request чтобы запросить конфиг.\n"
            "После подтверждения админом бот пришлет вам `ss://` ссылку."
        )
    await update.effective_message.reply_text(text, parse_mode=ParseMode.MARKDOWN)


async def cmd_request(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    settings: Settings = context.application.bot_data["settings"]
    store: StateStore = context.application.bot_data["store"]
    user = update.effective_user
    chat = update.effective_chat
    if not user or not chat:
        return

    issued_login = await store.get_issued_login(user.id)
    if issued_login:
        await update.effective_message.reply_text(
            "У вас уже есть выданный конфиг. Повторный запрос запрещен."
        )
        return

    if await store.has_active_request(user.id):
        await update.effective_message.reply_text(
            "У вас уже есть активная заявка. Подождите решения администратора."
        )
        return

    req_id = await store.create_request(
        user_id=user.id,
        username=user.username,
        full_name=user.full_name,
        chat_id=chat.id,
    )

    await update.effective_message.reply_text("Заявка отправлена администратору.")
    admin_text = (
        "*Новая заявка на конфиг*\n"
        f"- request_id: `{req_id}`\n"
        f"- user_id: `{user.id}`\n"
        f"- username: `{user.username or '-'}`\n"
        f"- full_name: `{user.full_name}`\n\n"
        "Нажмите *Принять* или *Отклонить*."
    )
    await context.bot.send_message(
        chat_id=settings.admin_telegram_id,
        text=admin_text,
        reply_markup=request_keyboard(req_id),
        parse_mode=ParseMode.MARKDOWN,
    )


async def on_request_decision(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> None:
    settings: Settings = context.application.bot_data["settings"]
    store: StateStore = context.application.bot_data["store"]
    query = update.callback_query
    if not query:
        return

    await query.answer()
    if query.from_user.id != settings.admin_telegram_id:
        await query.edit_message_text("Недостаточно прав.")
        return

    try:
        action, req_id = query.data.split(":", maxsplit=1)
    except Exception:
        await query.edit_message_text("Некорректный callback.")
        return

    request = await store.get_request(req_id)
    if not request:
        await query.edit_message_text("Заявка не найдена.")
        return

    if action == "reject":
        await store.set_status(req_id, "rejected")
        await store.clear_user_active(int(request["user_id"]))
        await context.bot.send_message(
            chat_id=int(request["chat_id"]),
            text="Заявка отклонена администратором.",
        )
        await query.edit_message_text(
            f"Заявка `{req_id}` отклонена.", parse_mode=ParseMode.MARKDOWN
        )
        return

    if action != "approve":
        await query.edit_message_text("Неизвестное действие.")
        return

    await store.set_status(req_id, "awaiting_admin_login")
    await store.set_admin_action(
        settings.admin_telegram_id,
        {"type": "approve_request", "request_id": req_id},
    )
    await query.edit_message_text(
        f"Заявка `{req_id}` принята.\nОтправьте логин для пользователя одним сообщением.",
        parse_mode=ParseMode.MARKDOWN,
    )


async def cmd_newcfg(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    settings: Settings = context.application.bot_data["settings"]
    store: StateStore = context.application.bot_data["store"]
    if not is_admin(update, settings):
        return

    await store.set_admin_action(settings.admin_telegram_id, {"type": "manual_issue"})
    await update.effective_message.reply_text(
        "Режим ручного выпуска.\nОтправьте логин пользователя одним сообщением."
    )


async def cmd_cancel(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    settings: Settings = context.application.bot_data["settings"]
    store: StateStore = context.application.bot_data["store"]
    if not is_admin(update, settings):
        return

    action = await store.pop_admin_action(settings.admin_telegram_id)
    if not action:
        await update.effective_message.reply_text("Нет активного ожидания.")
        return

    if action.get("type") == "approve_request":
        req_id = action.get("request_id", "")
        request = await store.get_request(req_id)
        if request:
            await store.set_status(req_id, "pending")
            await context.bot.send_message(
                chat_id=int(request["chat_id"]),
                text="Рассмотрение заявки остановлено. Попробуйте позже.",
            )
    await update.effective_message.reply_text("Ожидание отменено.")


async def on_admin_text(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    settings: Settings = context.application.bot_data["settings"]
    store: StateStore = context.application.bot_data["store"]
    if not is_admin(update, settings):
        return

    message = update.effective_message
    if not message or not message.text:
        return

    action = await store.pop_admin_action(settings.admin_telegram_id)
    if action is None:
        return

    login = message.text.strip()
    if not USERNAME_RE.match(login):
        await store.set_admin_action(settings.admin_telegram_id, action)
        await message.reply_text(
            "Невалидный логин. Разрешены: a-z A-Z 0-9 . _ -\n"
            "Отправьте логин еще раз."
        )
        return

    code, stdout, stderr = await run_script(
        settings.issue_script,
        login,
        settings.env_file,
        settings.users_file,
    )
    if code != 0:
        await store.set_admin_action(settings.admin_telegram_id, action)
        await message.reply_text(
            "Ошибка генерации конфига:\n"
            f"code={code}\n"
            f"{stderr.strip() or stdout.strip() or 'no output'}"
        )
        return

    apply_code, apply_out, apply_err = await run_script(settings.apply_script)
    if apply_code != 0:
        await store.set_admin_action(settings.admin_telegram_id, action)
        await message.reply_text(
            "Конфиг добавлен в реестр, но не применен на сервере:\n"
            f"code={apply_code}\n"
            f"{apply_err.strip() or apply_out.strip() or 'no output'}\n\n"
            "Исправьте ошибку и отправьте логин еще раз, либо /cancel."
        )
        return

    config = _extract_config(stdout)
    if action.get("type") == "manual_issue":
        await message.reply_text(
            f"```text\n{config}\n```",
            parse_mode=ParseMode.MARKDOWN,
        )
        return

    if action.get("type") != "approve_request":
        await message.reply_text("Неизвестное состояние ожидания.")
        return

    req_id = action.get("request_id", "")
    request = await store.get_request(req_id)
    if not request:
        await message.reply_text("Заявка не найдена.")
        return

    await context.bot.send_message(
        chat_id=int(request["chat_id"]),
        text=(
            "Ваш конфиг готов:\n\n"
            f"```text\n{config}\n```\n\n"
            "Импортируйте его в клиент Shadowsocks."
        ),
        parse_mode=ParseMode.MARKDOWN,
    )
    await message.reply_text(
        f"Конфиг выдан.\nrequest_id={req_id}\nlogin={login}\nuser_id={request['user_id']}"
    )
    await store.set_status(req_id, "issued")
    await store.set_issued_login(int(request["user_id"]), login)
    await store.clear_user_active(int(request["user_id"]))


async def cmd_users(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    settings: Settings = context.application.bot_data["settings"]
    if not is_admin(update, settings):
        return

    code, stdout, stderr = await run_script(settings.users_script, settings.users_file)
    if code != 0:
        await update.effective_message.reply_text(
            f"Ошибка списка пользователей: {stderr.strip() or stdout.strip()}"
        )
        return

    text = stdout.strip() or "(пусто)"
    await update.effective_message.reply_text(f"Пользователи:\n{text}")


async def cmd_configs(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    settings: Settings = context.application.bot_data["settings"]
    if not is_admin(update, settings):
        return

    code, stdout, stderr = await run_script(settings.users_script, settings.users_file)
    if code != 0:
        await update.effective_message.reply_text(
            f"Ошибка списка пользователей: {stderr.strip() or stdout.strip()}"
        )
        return

    users = _extract_usernames(stdout)
    if not users:
        await update.effective_message.reply_text("Пользователей нет.")
        return

    await update.effective_message.reply_text(
        "Выбери пользователя:", reply_markup=users_keyboard(sorted(users))
    )


async def on_config_show(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    settings: Settings = context.application.bot_data["settings"]
    query = update.callback_query
    if not query:
        return

    await query.answer()
    if query.from_user.id != settings.admin_telegram_id:
        await query.edit_message_text("Недостаточно прав.")
        return

    _, username = query.data.split(":", maxsplit=1)
    if not USERNAME_RE.match(username):
        await query.edit_message_text("Некорректный username.")
        return

    code, stdout, stderr = await run_script(
        settings.print_script, username, settings.env_file
    )
    if code != 0:
        await query.edit_message_text(
            f"Ошибка генерации конфига: {stderr.strip() or stdout.strip()}"
        )
        return

    config = _extract_config(stdout)
    text = f"Логин: `{username}`\n```text\n{config}\n```"
    if query.message:
        await query.message.reply_text(
            text,
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=delete_keyboard(username),
        )
        return

    await context.bot.send_message(
        chat_id=settings.admin_telegram_id,
        text=text,
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=delete_keyboard(username),
    )


async def on_config_delete(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    settings: Settings = context.application.bot_data["settings"]
    store: StateStore = context.application.bot_data["store"]
    query = update.callback_query
    if not query:
        return

    await query.answer()
    if query.from_user.id != settings.admin_telegram_id:
        await query.edit_message_text("Недостаточно прав.")
        return

    _, username = query.data.split(":", maxsplit=1)
    if not USERNAME_RE.match(username):
        await query.edit_message_text("Некорректный username.")
        return

    code, stdout, stderr = await run_script(
        settings.remove_script, username, settings.users_file
    )
    if code != 0:
        await query.edit_message_text(
            f"Ошибка удаления: {stderr.strip() or stdout.strip()}"
        )
        return

    apply_code, apply_out, apply_err = await run_script(settings.apply_script)
    if apply_code != 0:
        await query.edit_message_text(
            "Пользователь удален из реестра, но изменения не применены на сервере:\n"
            f"code={apply_code}\n"
            f"{apply_err.strip() or apply_out.strip() or 'no output'}"
        )
        return

    removed_users = await store.remove_issued_by_login(username)
    suffix = ""
    if removed_users:
        suffix = f"\nСнят лимит по user_id: {', '.join(map(str, removed_users))}"
    await query.edit_message_text(
        f"Конфиг `{username}` удален.{suffix}", parse_mode=ParseMode.MARKDOWN
    )


def build_app(settings: Settings) -> Application:
    app = Application.builder().token(settings.bot_token).build()
    store = StateStore(settings.state_file)
    app.bot_data["settings"] = settings
    app.bot_data["store"] = store

    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("request", cmd_request))
    app.add_handler(CommandHandler("newcfg", cmd_newcfg))
    app.add_handler(CommandHandler("users", cmd_users))
    app.add_handler(CommandHandler("configs", cmd_configs))
    app.add_handler(CommandHandler("cancel", cmd_cancel))

    app.add_handler(CallbackQueryHandler(on_request_decision, pattern=r"^(approve|reject):"))
    app.add_handler(CallbackQueryHandler(on_config_show, pattern=r"^cfgshow:"))
    app.add_handler(CallbackQueryHandler(on_config_delete, pattern=r"^cfgdel:"))
    app.add_handler(
        MessageHandler(filters.TEXT & ~filters.COMMAND, on_admin_text),
        group=1,
    )
    return app


async def _post_init(app: Application) -> None:
    store: StateStore = app.bot_data["store"]
    await store.load()


def main() -> None:
    settings = Settings.from_env()
    app = build_app(settings)
    app.post_init = _post_init
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
