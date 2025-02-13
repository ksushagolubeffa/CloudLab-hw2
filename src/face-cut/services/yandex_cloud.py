from time import sleep

import piexif
import requests
from PIL import Image
from requests_aws4auth import AWS4Auth

from settings import OBJECT_STORAGE_API_URL, FACES_MOUNT_POINT, ACCESS_KEY_ID, SECRET_ACCESS_KEY


def get_image(image_path):
    with Image.open(image_path) as image:
        image.load()
    return image


def set_mime_type(bucket, object_key, mime_type):
    url = f"{OBJECT_STORAGE_API_URL}/{bucket}/{object_key}"

    headers = {
        "Content-Type": mime_type,
        "X-Amz-Copy-Source": f"/{bucket}/{object_key}",
        "X-Amz-Metadata-Directive": "REPLACE",
    }

    auth = AWS4Auth(
        ACCESS_KEY_ID,
        SECRET_ACCESS_KEY,
        "ru-central1",
        "s3",
    )

    requests.put(url, headers=headers, auth=auth)


def save_image(image, image_path, exif=()):
    image.save(image_path, exif=piexif.dump(exif))
    sleep(1)
    set_mime_type(FACES_MOUNT_POINT, image_path.name, "image/jpeg")
