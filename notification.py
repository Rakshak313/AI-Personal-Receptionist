import os
import requests
from dotenv import load_dotenv
from plyer import notification


# ==========================================
# TELEGRAM SETTINGS
# ==========================================

load_dotenv()

# Read credentials from environment (see .env / .env.example).
# Never commit real tokens to version control.

BOT_TOKEN = os.getenv("TELEGRAM_TOKEN", "")

CHAT_ID = os.getenv("TELEGRAM_CHAT_ID", "")


# ==========================================
# Send Telegram Message
# ==========================================

def send_telegram(message):

    url = (
        f"https://api.telegram.org/"
        f"bot{BOT_TOKEN}/sendMessage"
    )


    data = {

        "chat_id": CHAT_ID,

        "text": message

    }


    try:

        response = requests.post(
            url,
            data=data,
            timeout=10
        )


        if response.status_code == 200:

            print(
                "Telegram notification sent."
            )

        else:

            print(
                "Telegram error:",
                response.text
            )


    except Exception as e:

        print(
            "Telegram connection error:",
            e
        )



# ==========================================
# Desktop + Telegram Notification
# ==========================================

def notify(name, reason):


    message = f"""
📞 New Call Received

👤 Caller:
{name}

📝 Reason:
{reason}

🤖 AI Receptionist
"""


    # Desktop notification

    try:

        notification.notify(

            title="New Call Received",

            message=(
                f"Caller: {name}\n"
                f"Reason: {reason[:100]}"
            ),

            timeout=10
        )


    except Exception as e:

        print(
            "Desktop notification error:",
            e
        )


    # Telegram notification

    send_telegram(
        message
    )