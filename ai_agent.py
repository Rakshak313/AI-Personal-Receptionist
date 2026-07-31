import requests
import re


OLLAMA_URL = "http://127.0.0.1:11434/api/generate"

MODEL = "phi3:latest"


SYSTEM_PROMPT = """
You are an AI Personal Receptionist for Rakshak.

You are answering a phone call.

STRICT RULES:
- Speak like a real human receptionist.
- Keep every reply under 15 words.
- Return only ONE sentence.
- Ask only ONE question at a time.
- Never use quotation marks.
- Never use bullet points.
- Never write emails.
- Never mention hotels, banks, companies, or fake businesses.
- Never create fake information.
- Do not repeat previous questions.
- Do not introduce yourself with a fake name.

Conversation flow:

Step 1:
Greet caller and ask their name.

Step 2:
After receiving name, ask the reason for calling.

Step 3:
After receiving reason, say that you will inform Rakshak.

Examples:

Hello, may I know your name please?

Thank you. May I know the reason for your call?

I have noted your message and will inform Rakshak.

"""


def clean_response(text):

    if not text:
        return ""


    # Remove quotes
    text = text.replace('"', "")
    text = text.replace("'", "")


    # Remove multiple lines
    text = text.replace("\n", " ")


    # Remove extra spaces
    text = re.sub(
        r"\s+",
        " ",
        text
    )


    text = text.strip()


    # Take only first sentence
    sentences = re.split(
        r'(?<=[.!?])\s+',
        text
    )


    if sentences:
        text = sentences[0]


    # Limit length
    words = text.split()

    if len(words) > 20:

        text = " ".join(
            words[:20]
        )


    return text.strip()



def ask_ai(message: str) -> str:


    prompt = f"""
{SYSTEM_PROMPT}


Current conversation:

{message}


AI Receptionist:
"""


    payload = {

        "model": MODEL,

        "prompt": prompt,

        "stream": False,


        "options": {

            "temperature": 0.1,

            "top_p": 0.7,

            "num_predict": 35

        }

    }



    try:


        response = requests.post(

            OLLAMA_URL,

            json=payload,

            timeout=120

        )


        response.raise_for_status()


        data = response.json()


        reply = data.get(
            "response",
            ""
        )


        reply = clean_response(
            reply
        )


        if not reply:

            return (
                "I have noted your message and will inform Rakshak."
            )


        return reply



    except requests.exceptions.ConnectionError:


        return (
            "AI service is unavailable right now."
        )



    except requests.exceptions.Timeout:


        return (
            "Please wait while I process your request."
        )



    except Exception as e:


        print(
            "AI Error:",
            e
        )


        return (
            "I have noted your message and will inform Rakshak."
        )