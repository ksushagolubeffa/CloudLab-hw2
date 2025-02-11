import json
from pathlib import Path
from uuid import uuid4

import piexif

from services.yandex_cloud import get_image, save_image
from settings import PHOTOS_MOUNT_POINT, FACES_MOUNT_POINT
from utils import crop_image


def handler(event, context):
    message = json.loads(event["messages"][0]["details"]["message"]["body"])
    object_key, rect = message["object_key"], message["rectangle"]

    image = get_image(Path("/function/storage", PHOTOS_MOUNT_POINT, object_key))
    face = crop_image(image, rect)
    metadata = {"0th": {
        piexif.ImageIFD.ImageDescription: object_key.encode("utf-8")
    }}
    save_image(face, Path("/function/storage", FACES_MOUNT_POINT, f"{uuid4()}.jpg"), exif=metadata)

    return {
        "statusCode": 200,
    }
