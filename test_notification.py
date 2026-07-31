import requests


# n8n webhook URL
# Replace this with your actual n8n webhook URL
N8N_WEBHOOK_URL = "YOUR_N8N_WEBHOOK_URL"


def notify(name, reason):

    data = {
        "caller_name": name,
        "reason": reason
    }

    try:

        response = requests.post(
            N8N_WEBHOOK_URL,
            json=data,
            timeout=10
        )

        if response.status_code == 200:
            print("Notification sent successfully.")

        else:
            print(
                f"Notification failed: {response.status_code}"
            )

    except Exception as e:

        print(
            f"Notification error: {e}"
        )