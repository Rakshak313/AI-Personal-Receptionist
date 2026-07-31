# 📞 AI Personal Receptionist

An intelligent, voice-based **AI receptionist** that answers your calls, greets the caller, asks for their name and the reason for calling, stores the details, and notifies you — powered by a local AI stack.

Built with **Python**, **Whisper** for speech recognition, **Ollama** for the AI brain, and **Asterisk + SIP** for telephony integration.

---

## 🧠 Overview

The AI Personal Receptionist turns any phone line into a smart assistant. When someone calls, the system:

1. **Answers** the call and greets the caller with a natural voice.
2. **Asks** for the caller's name.
3. **Asks** for the reason for the call.
4. **Logs** the call details to a local database.
5. **Notifies** the owner via desktop notification and Telegram.
6. **Replies** naturally using a local LLM, then says goodbye.

Everything runs **locally** — no cloud dependency for the AI brain.

---

## 🎯 Problem Statement

Small businesses and busy professionals miss important calls when they are unavailable. Traditional voicemail boxes feel cold, and callers rarely leave useful messages. Answering every call personally is impossible.

This project solves that by providing a **polite, intelligent, always-available receptionist** that captures the caller's name and purpose with a human-like conversation, stores it, and notifies the owner instantly — without ever needing a live human on the line.

---

## ✨ Features

- 🎙️ **Voice-based conversation** — full speech recognition (Whisper) and text-to-speech (pyttsx3)
- 🤖 **AI-powered replies** — Ollama local LLM generates natural, short receptionist responses
- 📞 **Telephony integration** — Asterisk PBX with PJSIP, tested with Linphone softphone (UDP)
- 💾 **Call logging** — every call saved to SQLite (`calls.db`)
- 🔔 **Instant notifications** — desktop popup + Telegram message on every call
- 📊 **Web dashboard** — Flask app to view call history
- 🛠️ **Asterisk tooling** — fix/repair scripts for PJSIP registration issues (duplicate transports, chan_sip conflicts)
- 🧪 **Test suite** — Python and shell tests for AI, notifications, and PJSIP repair logic

---

## 🏗️ Architecture

```
Caller (Linphone)
      │  SIP / RTP
      ▼
  Asterisk PBX  ──►  dialplan  ──►  [from-internal]
      │
      ▼
AI Personal Receptionist (Python)
      │
      ├── speech.py   ──►  Whisper (STT)  +  pyttsx3 (TTS)
      ├── ai_agent.py ──►  Ollama LLM (phi3)  ←  local, offline
      ├── database.py ──►  SQLite (calls.db)
      ├── notification.py ──►  Desktop + Telegram notifications
      └── main.py     ──►  conversation orchestration
```

---

## 🔁 Call Flow

```
1. Caller dials in via Linphone → registers with Asterisk (SIP/PJSIP)
2. Asterisk dialplan routes the call to the receptionist
3. AI greets the caller and asks for their name
4. Caller speaks → Whisper converts speech to text
5. AI asks for the reason of the call
6. Call details (name, reason, time) saved to SQLite
7. Owner notified via desktop notification + Telegram
8. Ollama generates a natural reply → spoken back to the caller
9. AI thanks the caller and ends the call
```

---

## 🛠️ Tech Stack

| Technology | Purpose |
|------------|---------|
| **Python 3** | Core application logic |
| **Whisper (OpenAI)** | Speech recognition (STT) |
| **pyttsx3** | Text-to-speech (TTS) |
| **Ollama (phi3)** | Local LLM for AI receptionist replies |
| **SQLite** | Call history storage |
| **Asterisk 18** | SIP PBX / call routing |
| **PJSIP** | SIP channel driver (UDP transport) |
| **Linphone** | SIP softphone (test client) |
| **Flask** | Web dashboard for call history |
| **Telegram Bot API** | Remote notifications |
| **python-dotenv** | Configuration via `.env` |

---

## 📦 Installation

### 1. Prerequisites

- **Python 3.9+** with `pip`
- **Ollama** installed and running locally (`ollama pull phi3`)
- **Whisper** (`openai-whisper`) — downloads the `base` model on first run
- **Asterisk 18** (for telephony) — e.g. on Ubuntu/WSL2
- **Linphone** (optional, for testing SIP registration)

### 2. Clone and set up

```bash
git clone https://github.com/Rakshak313/AI-Personal-Receptionist.git
cd AI-Personal-Receptionist

# Virtual environment
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate

# Dependencies
pip install -r requirements.txt

# Configuration
cp .env.example .env            # then fill in your real values
```

### 3. Install the Ollama model

```bash
ollama pull phi3:latest
```

---

## ⚙️ Configuration

Copy `.env.example` to `.env` and set your values:

```env
TELEGRAM_TOKEN=your_telegram_bot_token_here
TELEGRAM_CHAT_ID=your_telegram_chat_id_here
OLLAMA_URL=http://127.0.0.1:11434
AI_MODEL=phi3:latest
OWNER_NAME=Rakshak
```

| Variable | Description |
|----------|-------------|
| `TELEGRAM_TOKEN` | Bot token from [@BotFather](https://t.me/BotFather) |
| `TELEGRAM_CHAT_ID` | Your Telegram chat id (e.g. from @userinfobot) |
| `OLLAMA_URL` | Local Ollama server URL |
| `AI_MODEL` | Ollama model to use for replies |
| `OWNER_NAME` | Name used by the receptionist when taking messages |

> ⚠️ **Never commit your real `.env` file.** It is git-ignored by design.

---

## 🚀 How to Run

### Run the receptionist

```bash
python main.py
```

The app will greet callers, listen through the microphone, and save call details.

### View call history

```bash
python view_calls.py
```

### Start the web dashboard

```bash
python dashboard.py
# open http://127.0.0.1:5000
```

### Test modules

```bash
python test_ai.py
python test_telegram.py
python test_notification.py
```

### Asterisk / SIP setup (WSL2 + Linphone)

Sample configs are included:

```bash
# Copy sample PJSIP config (adapt paths for your system)
sudo cp pjsip_minimal.conf /etc/asterisk/pjsip.conf
sudo cp dialplan_from_internal.conf /etc/asterisk/extensions.conf

# Repair/verify scripts (run with sudo)
sudo bash fix_asterisk.sh
sudo bash repair_pjsip.sh
```

Test scripts (no root needed, run against temp files):

```bash
bash test_pjsip_fix.sh
bash test_repair_pjsip.sh
```

> ⚠️ **Security note:** The sample configs and repair scripts (`pjsip_minimal.conf`, `repair_pjsip.sh`) contain the **lab-only** SIP password `AIReceptionist@2026` for extension `1001` (local WSL2 + Linphone test setup). These are **not production credentials** — always change the SIP password before any real deployment.

---

## 🔮 Future Improvements

- 📡 **Live call forwarding** — Twilio / Exotel / SIP forwarding of answered calls
- 🔗 **n8n workflow integration** — webhook notifications for automation
- 🧠 **Gemini backup agent** — alternate LLM backend (`ai_agent_gemini_backup.py`)
- 🌍 **Multi-language support** — Whisper + TTS in more languages
- 🕒 **Smart scheduling** — route calls based on availability
- 📞 **Voicemail with AI transcription**
- 📈 **Analytics dashboard** — call trends, missed-call reports

---

## 📄 License

This project is for personal/educational use. See individual files for details.

---

*Made with ❤️ by Rakshak*
