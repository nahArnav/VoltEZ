import json
import os
import urllib.error
import urllib.request


def test_gemini():
    print("\n--- 1. Testing Google Gemini API ---")

    key = os.getenv("GEMINI_API_KEY", "").strip().strip("\"'").strip()

    if not key:
        print("ERROR: GEMINI_API_KEY is not set.")
        return

    models = [
        os.getenv("GEMINI_MODEL", "gemini-3.7-flash").removeprefix("models/"),
        "gemini-3.7-flash",
        "gemini-3.6-flash",
        "gemini-2.5-flash",
    ]

    for model in dict.fromkeys(models):
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

        headers = {
            "x-goog-api-key": key,
            "Content-Type": "application/json",
        }

        data = json.dumps(
            {
                "contents": [
                    {"parts": [{"text": "Say 'VoltEZ Gemini Connected successfully!' in 5 words."}]}
                ]
            }
        ).encode("utf-8")

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

                print(f"Model {model}: HTTP {status}")

                result = json.loads(body)
                text = result["candidates"][0]["content"]["parts"][0]["text"]

                print(f"--> Gemini Response: {text.strip()}")
                return

        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8")
            print(f"Model {model}: HTTP {e.code} -> {err_body[:200]}")

        except Exception as e:
            print(f"--> Exception for {model}: {e}")

    print("Gemini connection failed for all tested models.")


if __name__ == "__main__":
    test_gemini()
