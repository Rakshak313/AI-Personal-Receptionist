from ollama import chat


def ask_ai(message):

    prompt = f"""
You are an AI Personal Receptionist.

Your job:
- Welcome callers politely.
- Ask the caller's name if not provided.
- Ask the reason for calling.
- Keep responses short and professional.
- Do not give long explanations.
- Remember the conversation context.

Conversation:
{message}
"""

    try:
        response = chat(
            model="tinyllama",
            messages=[
                {
                    "role": "system",
                    "content": "You are a professional AI receptionist for a business."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            options={
                "temperature": 0.3
            }
        )

        return response["message"]["content"]

    except Exception as e:
        return f"AI error: {str(e)}"