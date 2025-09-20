#!/bin/bash
set -e

# ================= CONFIG =================
BOT_USER="botuser"
BOT_DIR="/home/$BOT_USER/sandunibot"
BOT_FILE="bot.py"
SERVICE_NAME="sandunibot"
PYTHON_BIN="$BOT_DIR/venv/bin/python"

# Telegram credentials
API_ID="26204033"
API_HASH="5b104e183a87f8f7f508ca4a776ba707"
BOT_TOKEN="8045038464:AAEtuw1RAvOO2rxJhYLwaCQYNZkZ9Yl5bxY"

# ================= SCRIPT =================
echo "=== 1. Installing dependencies ==="
sudo apt update
sudo apt install -y python3 python3-venv python3-pip tmux

echo "=== 2. Creating dedicated user ($BOT_USER) ==="
if id "$BOT_USER" &>/dev/null; then
    echo "User $BOT_USER already exists, skipping creation."
else
    sudo adduser --disabled-password --gecos "" $BOT_USER
fi

echo "=== 3. Creating bot directory ==="
sudo mkdir -p $BOT_DIR
sudo chown $BOT_USER:$BOT_USER $BOT_DIR

echo "=== 4. Setting up Python virtual environment ==="
sudo -u $BOT_USER python3 -m venv $BOT_DIR/venv
sudo -u $BOT_USER $PYTHON_BIN -m pip install --upgrade pip
sudo -u $BOT_USER $PYTHON_BIN -m pip install telethon

echo "=== 5. Creating bot.py ==="
sudo -u $BOT_USER tee $BOT_DIR/$BOT_FILE > /dev/null <<'EOF'
import json
import os
import asyncio
from telethon import TelegramClient, events

# ===== CONFIG =====
api_id = 26204033
api_hash = "5b104e183a87f8f7f508ca4a776ba707"
bot_token = "8045038464:AAEtuw1RAvOO2rxJhYLwaCQYNZkZ9Yl5bxY"

DATA_FILE = "bot_data.json"
PASSWORD = "hunter@Nawoo"   # 🔑 change this to your own password

# ===== LOAD DATA =====
if os.path.exists(DATA_FILE):
    with open(DATA_FILE, "r") as f:
        data = json.load(f)
    if "authorized_users" not in data:
        data["authorized_users"] = []
    if "source_ids" not in data:
        data["source_ids"] = []
    if "dest_ids" not in data:
        data["dest_ids"] = []
    if "footer" not in data:
        data["footer"] = "\n\n— Forwarded by SanduniBot"
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=4)
else:
    data = {
        "source_ids": [],
        "dest_ids": [],
        "footer": "\n\n— Forwarded by SanduniBot",
        "authorized_users": []
    }
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=4)

# ===== SAVE DATA =====
def save_data():
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=4)

# ===== CLIENTS =====
userbot = TelegramClient("userbot_session", api_id, api_hash)
bot = TelegramClient("bot_session", api_id, api_hash)

# ===== USERBOT: MESSAGE FORWARDER =====
@userbot.on(events.NewMessage())
async def forward_handler(event):
    if not data["source_ids"] or not data["dest_ids"]:
        return
    if event.chat_id not in data["source_ids"]:
        return
    if not event.raw_text:
        return

    text = event.raw_text

    if (("long" in text.lower() or "short" in text.lower()) and
        ("entry point" in text.lower() or "cross" in text.lower())):

        msg_with_footer = text + data["footer"]
        for dest in data["dest_ids"]:
            try:
                await userbot.send_message(dest, msg_with_footer)
            except Exception as e:
                print(f"⚠️ Failed to send message to {dest}: {e}")

# ===== BOT: COMMAND HANDLERS =====
def is_authorized(user_id: int) -> bool:
    return user_id in data["authorized_users"]

@bot.on(events.NewMessage(pattern="/start"))
async def start_handler(event):
    if not is_authorized(event.sender_id):
        await event.respond("🔒 Please enter password using /login <password>")
        return
    await event.respond("👋 Hello! I'm your forward bot.\nUse /help to see commands.")

@bot.on(events.NewMessage(pattern=r"^/login (.+)"))
async def login_handler(event):
    pwd = event.pattern_match.group(1).strip()
    if pwd == PASSWORD:
        if event.sender_id not in data["authorized_users"]:
            data["authorized_users"].append(event.sender_id)
            save_data()
        await event.respond("✅ Login successful! You can now use commands.\n /help to see commands.")
    else:
        await event.respond("❌ Wrong password. Try again.")

@bot.on(events.NewMessage(pattern="/help"))
async def help_handler(event):
    if not is_authorized(event.sender_id):
        await event.respond("🔒 Unauthorized. Use /login <password>")
        return
    help_text = (
        "📌 Commands:\n"
        "/start - Start bot\n"
        "/help - Show help\n"
        "/setfooter <text> - Change footer\n"
        "/addsource <chat_id> - Add source group/channel\n"
        "/adddest <chat_id> - Add destination group/channel\n"
        "/removesource <chat_id> - Remove source\n"
        "/removedest <chat_id> - Remove destination\n"
        "/listsources - Show all sources\n"
        "/listdests - Show all destinations\n"
        "/showconfig - Show current config"
    )
    await event.respond(help_text)

@bot.on(events.NewMessage(pattern=r"^/setfooter (.+)"))
async def set_footer_handler(event):
    if not is_authorized(event.sender_id):
        await event.respond("🔒 Unauthorized. Use /login <password>")
        return
    data["footer"] = "\n\n" + event.pattern_match.group(1)
    save_data()
    await event.respond(f"✅ Footer updated:\n{data['footer']}")

@bot.on(events.NewMessage(pattern=r"^/addsource (-?\d+)"))
async def add_source_handler(event):
    if not is_authorized(event.sender_id):
        await event.respond("🔒 Unauthorized.")
        return
    new_id = int(event.pattern_match.group(1))
    if new_id not in data["source_ids"]:
        data["source_ids"].append(new_id)
        save_data()
        await event.respond(f"✅ Added source: {new_id}")
    else:
        await event.respond("⚠️ Already in sources.")

@bot.on(events.NewMessage(pattern=r"^/adddest (-?\d+)"))
async def add_dest_handler(event):
    if not is_authorized(event.sender_id):
        await event.respond("🔒 Unauthorized.")
        return
    new_id = int(event.pattern_match.group(1))
    if new_id not in data["dest_ids"]:
        data["dest_ids"].append(new_id)
        save_data()
        await event.respond(f"✅ Added destination: {new_id}")
    else:
        await event.respond("⚠️ Already in destinations.")

@bot.on(events.NewMessage(pattern=r"^/removesource (-?\d+)"))
async def remove_source_handler(event):
    if not is_authorized(event.sender_id):
        await event.respond("🔒 Unauthorized.")
        return
    rm_id = int(event.pattern_match.group(1))
    if rm_id in data["source_ids"]:
        data["source_ids"].remove(rm_id)
        save_data()
        await event.respond(f"🗑️ Removed source: {rm_id}")
    else:
        await event.respond("⚠️ Source not found.")

@bot.on(events.NewMessage(pattern=r"^/removedest (-?\d+)"))
async def remove_dest_handler(event):
    if not is_authorized(event.sender_id):
        await event.respond("🔒 Unauthorized.")
        return
    rm_id = int(event.pattern_match.group(1))
    if rm_id in data["dest_ids"]:
        data["dest_ids"].remove(rm_id)
        save_data()
        await event.respond(f"🗑️ Removed destination: {rm_id}")
    else:
        await event.respond("⚠️ Destination not found.")

@bot.on(events.NewMessage(pattern="/listsources"))
async def list_sources_handler(event):
    if not is_authorized(event.sender_id):
        await event.respond("🔒 Unauthorized.")
        return
    sources = "\n".join(str(i) for i in data["source_ids"]) or "None"
    await event.respond(f"📋 Sources:\n{sources}")

@bot.on(events.NewMessage(pattern="/listdests"))
async def list_dests_handler(event):
    if not is_authorized(event.sender_id):
        await event.respond("🔒 Unauthorized.")
        return
    dests = "\n".join(str(i) for i in data["dest_ids"]) or "None"
    await event.respond(f"📋 Destinations:\n{dests}")

@bot.on(events.NewMessage(pattern="/showconfig"))
async def show_config_handler(event):
    if not is_authorized(event.sender_id):
        await event.respond("🔒 Unauthorized.")
        return
    await event.respond(
        f"⚙️ Config:\nSources: {data['source_ids']}\n"
        f"Destinations: {data['dest_ids']}\n"
        f"Footer: {data['footer']}"
    )

# ===== RUN BOTH CLIENTS =====
async def main():
    await userbot.start()
    await bot.start(bot_token=bot_token)
    print("✅ Bot Running Successfully...")
    await asyncio.gather(
        userbot.run_until_disconnected(),
        bot.run_until_disconnected()
    )

if __name__ == "__main__":
    asyncio.run(main())

EOF

echo "=== 6. Creating systemd service ==="
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<EOF
[Unit]
Description=Sanduni Telegram Bot
After=network.target

[Service]
Type=simple
User=$BOT_USER
WorkingDirectory=$BOT_DIR
ExecStart=$PYTHON_BIN $BOT_DIR/$BOT_FILE
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo "=== 7. Enabling and starting service ==="
sudo systemctl daemon-reload
sudo systemctl enable --now $SERVICE_NAME

echo "=== Setup complete! ==="
echo "Use 'sudo journalctl -u $SERVICE_NAME -f' to view logs."
echo "Bot will start automatically on server reboot."
