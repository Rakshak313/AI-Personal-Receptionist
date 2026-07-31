from database import get_calls

calls = get_calls()

print("\n========== CALL HISTORY ==========\n")

if not calls:
    print("No calls found.")
else:
    for call in calls:
        print("-" * 50)
        print(f"ID      : {call[0]}")
        print(f"Name    : {call[1]}")
        print(f"Reason  : {call[2]}")
        print(f"Time    : {call[3]}")