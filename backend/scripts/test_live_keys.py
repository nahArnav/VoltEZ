import json
import os
import urllib.error
import urllib.request


def test_gemini():
    print("\n--- 1. Testing Google Gemini API ---")

    key = os.getenv("GEMINI_API_KEY")

    if not key:
        print("ERROR: GEMINI_API_KEY is not set.")
        return

    models = [
        "models/gemini-2.0-flash",
        "models/gemini-2.0-flash-exp",
        "models/gemini-flash-latest",
        "models/gemini-pro-latest",
    ]

    for m in models:
        url = (
            f"https://generativelanguage.googleapis.com/v1beta/"
            f"{m}:generateContent?key={key}"
        )

        headers = {
            "x-goog-api-key": key,
            "Content-Type": "application/json",
        }

        data = json.dumps({
            "contents": [
                {
                    "parts": [
                        {
                            "text": "Say 'VoltEZ Gemini Connected successfully!' in 5 words."
                        }
                    ]
                }
            ]
        }).encode("utf-8")

        req = urllib.request.Request(
            url,
            data=data,
            headers=headers,
            method="POST",
        )

        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                status = resp.status
                body = resp.read().decode("utf-8")

                print(f"Model {m}: HTTP {status}")

                result = json.loads(body)
                text = result["candidates"][0]["content"]["parts"][0]["text"]

                print(f"--> Gemini Response: {text.strip()}")
                return

        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8")
            print(f"Model {m}: HTTP {e.code} -> {err_body[:200]}")

        except Exception as e:
            print(f"--> Exception for {m}: {e}")

    print("Gemini connection failed for all tested models.")


if __name__ == "__main__":
    test_gemini()
