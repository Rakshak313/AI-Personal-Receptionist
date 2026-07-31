import os
import tempfile
import time
import wave

import pyaudio
import pyttsx3
import whisper


# =====================================================
# AUDIO SETTINGS
# =====================================================

CHUNK = 1024
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 16000
RECORD_SECONDS = 6


# =====================================================
# TEXT TO SPEECH
# =====================================================

engine = pyttsx3.init()

engine.setProperty(
    "rate",
    170
)

engine.setProperty(
    "volume",
    1.0
)


# =====================================================
# LOAD WHISPER
# =====================================================

print("Loading Whisper model...")

model = whisper.load_model(
    "base"
)

print("Whisper model loaded.\n")



# =====================================================
# FIND MICROPHONES
# =====================================================

def get_microphones():

    audio = pyaudio.PyAudio()

    devices = []


    print("=" * 70)
    print("AVAILABLE MICROPHONES")
    print("=" * 70)


    for i in range(audio.get_device_count()):

        info = audio.get_device_info_by_index(i)

        if info["maxInputChannels"] > 0:

            name = info["name"]

            print(
                f"{i} : {name}"
            )


            devices.append(
                {
                    "index": i,
                    "name": name
                }
            )


    print("=" * 70)


    audio.terminate()

    return devices



MICROPHONES = get_microphones()



# =====================================================
# AUTO SELECT MICROPHONE
# =====================================================

def select_microphone():

    priority_words = [

        "bluetooth",
        "headset",
        "airpods",
        "earphone",
        "earbuds",
        "wireless",
        "microphone",
        "realtek",
        "audio"

    ]


    # First priority
    for mic in MICROPHONES:

        name = mic["name"].lower()

        for word in priority_words:

            if word in name:

                print(
                    "Selected microphone:",
                    mic["name"]
                )

                return mic["index"]



    # fallback

    if MICROPHONES:

        return MICROPHONES[0]["index"]



    return None



MIC_DEVICE_INDEX = select_microphone()



# =====================================================
# SPEAK
# =====================================================

def speak(text):

    print(
        "\nAI:",
        text,
        "\n"
    )

    engine.say(text)

    engine.runAndWait()



# =====================================================
# CLEAN WHISPER RESULT
# =====================================================

def clean_text(text):

    if not text:
        return ""


    text = text.strip()


    # Remove repeated words

    words=text.split()


    result=[]


    for w in words:

        if not result or result[-1] != w:

            result.append(w)


    text=" ".join(result)


    bad=[

        "thank you",
        "you",
        "music",
        "subtitles"

    ]


    if text.lower() in bad:

        return ""


    return text



# =====================================================
# LISTEN
# =====================================================

def listen():


    audio=pyaudio.PyAudio()


    frames=[]


    try:


        print(
            "\nTrying microphone device:",
            MIC_DEVICE_INDEX
        )


        stream=audio.open(

            format=FORMAT,

            channels=CHANNELS,

            rate=RATE,

            input=True,

            input_device_index=MIC_DEVICE_INDEX,

            frames_per_buffer=CHUNK

        )


        print(
            "Microphone connected"
        )


        for i in [3,2,1]:

            print(i)

            time.sleep(1)



        print(
            "\nSpeak now..."
        )


        for _ in range(
            int(RATE / CHUNK * RECORD_SECONDS)
        ):

            data=stream.read(

                CHUNK,

                exception_on_overflow=False

            )

            frames.append(data)



        print(
            "Recording complete."
        )


        stream.stop_stream()

        stream.close()



    except Exception as e:


        print(
            "Microphone error:",
            e
        )

        return ""



    finally:

        audio.terminate()



    temp=tempfile.NamedTemporaryFile(

        delete=False,

        suffix=".wav"

    )


    filename=temp.name

    temp.close()



    try:


        wf=wave.open(

            filename,

            "wb"

        )


        wf.setnchannels(CHANNELS)

        wf.setsampwidth(
            pyaudio.get_sample_size(FORMAT)
        )

        wf.setframerate(RATE)

        wf.writeframes(
            b"".join(frames)
        )


        wf.close()



        print(
            "Transcribing..."
        )


        result=model.transcribe(

            filename,

            language="en",

            fp16=False,

            temperature=0,

            verbose=False

        )


        text=clean_text(
            result["text"]
        )


        if not text:

            print(
                "No speech detected.\n"
            )

            return ""



        print(
            "You:",
            text
        )


        return text



    except Exception as e:


        print(
            "Whisper Error:",
            e
        )


        return ""



    finally:


        if os.path.exists(filename):

            os.remove(filename)