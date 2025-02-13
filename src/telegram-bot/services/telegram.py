import json

import requests

from services.yandex_cloud import get_image_bytes
from settings import TELEGRAM_API_URL
from utils import chunks


def send_message(reply_text, input_message):
    url = f"{TELEGRAM_API_URL}/sendMessage"

    data = {
        "chat_id": input_message["chat"]["id"],
        "text": reply_text,
        "reply_parameters": {
            "message_id": input_message["message_id"],
        },
    }

    requests.post(url=url, json=data)


def send_photo(photo_url, input_message, local_file=False):
    url = f"{TELEGRAM_API_URL}/sendPhoto"

    data = {
        "chat_id": input_message["chat"]["id"],
        "photo": photo_url,
        "reply_parameters": {
            "message_id": input_message["message_id"],
        },
    }

    if not local_file:
        response = requests.post(url=url, json=data)
    else:
        del data["photo"]
        data["reply_parameters"] = json.dumps(data["reply_parameters"])
        response = requests.post(url=url, data=data, files={"photo": open(photo_url, "rb")})

    return response.json()["result"]["photo"][-1]["file_unique_id"]


def send_photo_group(photo_paths, input_message):
    if len(photo_paths) == 1:
        return send_photo(photo_paths[0], input_message, local_file=True)

    url = f"{TELEGRAM_API_URL}/sendMediaGroup"

    data = {
        "chat_id": input_message["chat"]["id"],
        "reply_parameters": json.dumps({
            "message_id": input_message["message_id"],
        }),
    }

    for group in chunks(photo_paths, 10):
        data["media"] = json.dumps([{"type": "photo", "media": f"attach://{photo_path.name}"} for photo_path in group])
        files = {photo_path.name: get_image_bytes(photo_path) for photo_path in group}

        requests.post(url=url, data=data, files=files)
