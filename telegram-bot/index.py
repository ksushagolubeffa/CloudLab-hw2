import json
from pathlib import Path

from services.images import (set_tg_file_unique_id, set_name, rewrite_metadata,
                             get_face_without_name, get_face_by_tg_file_unique_id, get_originals_by_name)
from services.telegram import send_message, send_photo, send_photo_group
from settings import API_GATEWAY_URL, FACES_MOUNT_POINT, PHOTOS_MOUNT_POINT


def handle_message(message):
    if (text := message.get("text")) and text == "/start":
        pass

    elif text := message.get("text") and text == "/getface":
        object_key = get_face_without_name()
        if not object_key:
            send_message("Нет лиц с незаданным именем", message)
            return

        file_unique_id = send_photo(f"{API_GATEWAY_URL}?face={object_key}", message)
        rewrite_metadata(FACES_MOUNT_POINT, object_key, set_tg_file_unique_id, file_unique_id)

    elif (text := message.get("text")) and (reply_message := message.get("reply_to_message", {})):
        file_unique_id = reply_message.get("photo", [{}])[-1].get("file_unique_id")
        if not file_unique_id:
            return

        object_key = get_face_by_tg_file_unique_id(file_unique_id)
        rewrite_metadata(FACES_MOUNT_POINT, object_key, set_name, text)

    elif (text := message.get("text")) and text.startswith("/find"):
        name = text[6:]

        originals = get_originals_by_name(name)
        if not originals:
            send_message(f"Фотографии с {name} не найдены", message)
            return

        send_photo_group([Path("/function/storage", PHOTOS_MOUNT_POINT, original) for original in originals], message)

    else:
        send_message("Ошибка", message)


def handler(event, context):
    update = json.loads(event["body"])
    message = update.get("message")

    if message:
        handle_message(message)

    return {
        "statusCode": 200,
    }
