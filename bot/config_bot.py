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
    users_script: str
    configs_script: str
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
                "ISSUE_SCRIPT_PATH", "/opt/opensocks/scripts/issue_ss_config.sh"
            ),
            users_script=os.getenv(
                "LIST_USERS_SCRIPT_PATH", "/opt/opensocks/scripts/list_ss_users.sh"
            ),
            configs_script=os.getenv(
                "LIST_CONFIGS_SCRIPT_PATH", "/opt/opensocks/scripts/list_ss_configs.sh"
            ),
            env_file=os.getenv("OPENSOCKS_ENV_FILE", "/opt/opensocks/deploy/.env.server"),
            users_file=os.getenv("OPENSOCKS_USERS_FILE", "/opt/opensocks/deploy/users.txt"),
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
            "awaiting_login_by_admin": {},
        }

    async def load(self) -> None:
        async with self.lock:
            if self.path.exists():
                raw = self.path.read_text(encoding="utf-8")
                if raw.strip():
                    self.data = json.loads(raw)
            self.data.setdefault("requests", {})
            self.data.setdefault("active_by_user", {})
            self.data.setdefault("awaiting_login_by_admin", {})
            await self._save_locked()

    async def save(self) -> None:
        async with self.lock:
            await self._save_locked()

    async def _save_locked(self) -> None:
        self.path.write_text(
            json.dumps(self.data, ensure_ascii=False, indent=2, sort_keys=True),
            encoding="utf-8",
        )

    async def create_request(
        self, user_id: int, username: str | None, full_name: str, chat_id: int
    ) -> str | None:
        async with self.lock:
            user_key = str(user_id)
            if user_key in self.data["active_by_user"]:
                return None

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
            self.data["active_by_user"][user_key] = req_id
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

    async def set_admin_waiting(self, admin_id: int, req_id: str) -> None:
        async with self.lock:
            self.data["awaiting_login_by_admin"][str(admin_id)] = req_id
            await self._save_locked()

    async def pop_admin_waiting(self, admin_id: int) -> str | None:
        async with self.lock:
            req_id = self.data["awaiting_login_by_admin"].pop(str(admin_id), None)
            await self._save_locked()
            return req_id

    async def clear_user_active(self, user_id: int) -> None:
        async with self.lock:
            self.data["active_by_user"].pop(str(user_id), None)
            await self._save_locked()


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


async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    settings: Settings = context.application.bot_data["settings"]
    if is_admin(update, settings):
        text = (
            "Админ-режим.\n"
            "Команды:\n"
            "/users - список пользователей\n"
            "/configs - список конфигов\n"
            "/cancel - отменить ожидание логина"
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

    req_id = await store.create_request(
        user_id=user.id,
        username=user.username,
        full_name=user.full_name,
        chat_id=chat.id,
    )

    if req_id is None:
        await update.effective_message.reply_text(
            "У вас уже есть активная заявка. Подождите решения администратора."
        )
        return

    await update.effective_message.reply_text("Заявка отправлена администратору.")
    admin_text = (
        "*Новая заявка на конфиг*\n"
        f"- request_id: `{req_id}`\n"
        f"- user_id: `{user.id}`\n"
        f"- username: `{user.username or '-'}'\n"
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
        await query.edit_message_text(f"Заявка `{req_id}` отклонена.", parse_mode=ParseMode.MARKDOWN)
        return

    if action != "approve":
        await query.edit_message_text("Неизвестное действие.")
        return

    await store.set_status(req_id, "awaiting_admin_login")
    await store.set_admin_waiting(settings.admin_telegram_id, req_id)
    await query.edit_message_text(
        f"Заявка `{req_id}` принята.\nОтправьте логин для пользователя одним сообщением.",
        parse_mode=ParseMode.MARKDOWN,
    )


async def cmd_cancel(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    settings: Settings = context.application.bot_data["settings"]
    store: StateStore = context.application.bot_data["store"]
    if not is_admin(update, settings):
        return

    req_id = await store.pop_admin_waiting(settings.admin_telegram_id)
    if req_id is None:
        await update.effective_message.reply_text("Нет активного ожидания логина.")
        return

    request = await store.get_request(req_id)
    if request:
        await store.set_status(req_id, "pending")
        await context.bot.send_message(
            chat_id=int(request["chat_id"]),
            text="Рассмотрение заявки остановлено. Попробуйте позже.",
        )
    await update.effective_message.reply_text("Ожидание логина отменено.")


async def on_admin_text(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    settings: Settings = context.application.bot_data["settings"]
    store: StateStore = context.application.bot_data["store"]
    if not is_admin(update, settings):
        return

    message = update.effective_message
    if not message or not message.text:
        return

    req_id = await store.pop_admin_waiting(settings.admin_telegram_id)
    if req_id is None:
        return

    login = message.text.strip()
    if not USERNAME_RE.match(login):
        await message.reply_text(
            "Невалидный логин. Разрешены: a-z A-Z 0-9 . _ -\n"
            "Отправьте /cancel и заново одобрите заявку."
        )
        return

    request = await store.get_request(req_id)
    if not request:
        await message.reply_text("Заявка не найдена.")
        return

    code, stdout, stderr = await run_script(
        settings.issue_script,
        login,
        settings.env_file,
        settings.users_file,
    )
    if code != 0:
        await message.reply_text(
            "Ошибка генерации конфига:\n"
            f"code={code}\n"
            f"{stderr.strip() or stdout.strip() or 'no output'}"
        )
        await store.set_status(req_id, "error")
        await store.clear_user_active(int(request["user_id"]))
        return

    config = stdout.strip().splitlines()[-1]
    await context.bot.send_message(
        chat_id=int(request["chat_id"]),
        text=(
            "Ваш конфиг готов:\n\n"
            f"`{config}`\n\n"
            "Импортируйте его в клиент Shadowsocks."
        ),
        parse_mode=ParseMode.MARKDOWN,
    )
    await message.reply_text(
        f"Конфиг выдан.\nrequest_id={req_id}\nlogin={login}\nuser_id={request['user_id']}"
    )

    await store.set_status(req_id, "issued")
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

    code, stdout, stderr = await run_script(
        settings.configs_script, settings.env_file, settings.users_file
    )
    if code != 0:
        await update.effective_message.reply_text(
            f"Ошибка списка конфигов: {stderr.strip() or stdout.strip()}"
        )
        return

    text = stdout.strip() or "(пусто)"
    if len(text) > 3800:
        text = text[:3800] + "\n... (truncated)"
    await update.effective_message.reply_text(text)


def build_app(settings: Settings) -> Application:
    app = Application.builder().token(settings.bot_token).build()
    store = StateStore(settings.state_file)
    app.bot_data["settings"] = settings
    app.bot_data["store"] = store

    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("request", cmd_request))
    app.add_handler(CommandHandler("users", cmd_users))
    app.add_handler(CommandHandler("configs", cmd_configs))
    app.add_handler(CommandHandler("cancel", cmd_cancel))
    app.add_handler(CallbackQueryHandler(on_request_decision, pattern=r"^(approve|reject):"))
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
