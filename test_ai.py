from ai_agent import ask_ai


print("=" * 50)
print("Testing AI Personal Receptionist")
print("=" * 50)


conversation = """
Caller name: Ramesh

Caller reason:
Wants to discuss website development project.

Generate receptionist reply.
"""


response = ask_ai(conversation)


print("\nAI Response:\n")
print(response)