import requests

WEBHOOK_URL = "YOUR_N8N_WEBHOOK_URL"


def send_to_n8n(name, reason):

    payload = {
        "caller_name": name,
        "reason": reason
    }

    try:

        requests.post(
            WEBHOOK_URL,
            json=payload,
            timeout=10
        )

        print("✓ Sent to n8n")

    except Exception as e:

        print("n8n Error:", e)