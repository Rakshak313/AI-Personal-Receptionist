from datetime import datetime

from speech import listen, speak
from database import save_call
from ai_agent import ask_ai

# --------------------------------------------------
# Optional imports
# --------------------------------------------------

try:
    from notification import notify
except ImportError:
    def notify(name, reason):
        pass

try:
    from settings import GREETING, OWNER_NAME
except ImportError:
    GREETING = (
        "Hello. Thank you for calling. "
        "May I know your name please?"
    )
    OWNER_NAME = "Rakshak"


MAX_RETRIES = 3


# --------------------------------------------------
# Utility Functions
# --------------------------------------------------

def clean_text(text):
    """
    Clean speech recognition output.
    """

    if not text:
        return None

    text = text.strip()

    while "  " in text:
        text = text.replace("  ", " ")

    text = text.strip(".,!? ")

    if len(text) < 2:
        return None

    return text


def get_voice_input(prompt):
    """
    Speak prompt and retry if speech is not detected.
    """

    for attempt in range(MAX_RETRIES):

        speak(prompt)

        text = clean_text(listen())

        if text:
            return text

        if attempt < MAX_RETRIES - 1:
            speak(
                "Sorry, I couldn't understand. "
                "Please say it again."
            )

    return None


def print_call_summary(name, reason):
    """
    Print call details.
    """

    print("\n" + "=" * 60)
    print("              NEW CALL RECEIVED")
    print("=" * 60)
    print(f"Caller Name : {name}")
    print(f"Reason      : {reason}")
    print(f"Time        : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60 + "\n")


# --------------------------------------------------
# Main Program
# --------------------------------------------------

def main():

    print("\n" + "=" * 60)
    print("          AI PERSONAL RECEPTIONIST")
    print("=" * 60)

    try:

        # ------------------------------------------
        # Ask Name
        # ------------------------------------------

        name = get_voice_input(GREETING)

        if not name:
            speak(
                "Sorry, I couldn't hear your name. "
                "Please call again later."
            )
            return

        # ------------------------------------------
        # Ask Reason
        # ------------------------------------------

        reason = get_voice_input(
            f"Thank you {name}. "
            "Could you please tell me the reason for your call?"
        )

        if not reason:
            speak(
                "Sorry, I couldn't understand the reason "
                "for your call. Please call again later."
            )
            return

        # ------------------------------------------
        # Save Database
        # ------------------------------------------

        save_call(name, reason)

        # ------------------------------------------
        # Desktop Notification
        # ------------------------------------------

        try:
            notify(name, reason)
        except Exception as e:
            print(f"Notification Error: {e}")

        # ------------------------------------------
        # Console Summary
        # ------------------------------------------

        print_call_summary(name, reason)

        # ------------------------------------------
        # AI Receptionist Response
        # ------------------------------------------

        conversation = f"""
Caller Name: {name}

Reason for calling:
{reason}

Generate a short and natural phone response.
"""

        ai_reply = ask_ai(conversation)

        print("\n" + "=" * 60)
        print("AI RECEPTIONIST")
        print("=" * 60)
        print(ai_reply)
        print("=" * 60 + "\n")

        speak(ai_reply)

        speak(
            f"I will inform {OWNER_NAME} about your call."
        )

        speak(
            "Thank you for calling. Have a great day."
        )

        print("\nWaiting for future call forwarding...\n")

        # ==========================================
        # Future Integration
        # ==========================================
        #
        # Twilio
        # Exotel
        # SIP
        # Asterisk
        #
        # forward_call(
        #     caller_name=name,
        #     reason=reason
        # )
        #
        # ==========================================

        print("Call forwarding module is not connected yet.")

    except KeyboardInterrupt:

        print("\nApplication stopped by user.")

        speak("Receptionist has been stopped.")

    except Exception as e:

        print(f"\nUnexpected Error: {e}")

        speak(
            "Sorry. An unexpected error occurred."
        )


if __name__ == "__main__":
    main()