from pathlib import Path
from typing import Literal

import piexif
from PIL import Image

from services.yandex_cloud import get_image, save_image
from settings import FACES_MOUNT_POINT

Idf = Literal["0th", "Exif", "GPS", "1st", "thumbnail"]


def get_value_from_metadata(image, idf: Idf, key):
    if not (exif := image.info.get("exif")):
        return None

    exif = piexif.load(exif)
    value = exif[idf].get(key)

    if not value:
        return None

    return value.decode("utf-8")


def get_original_path(image):
    return get_value_from_metadata(image, "0th", piexif.ImageIFD.ImageDescription)


def get_name(image):
    return get_value_from_metadata(image, "Exif", piexif.ExifIFD.UserComment)


def get_tg_file_unique_id(image):
    return get_value_from_metadata(image, "0th", piexif.ImageIFD.DocumentName)


def add_value_to_metadata(image, idf: Idf, key, value):
    if not (exif := image.info.get("exif")):
        exif = piexif.dump(())

    exif = piexif.load(exif)
    exif[idf][key] = value.encode("utf-8")

    return exif


def set_name(image, name):
    return add_value_to_metadata(image, "Exif", piexif.ExifIFD.UserComment, name)


def set_tg_file_unique_id(image, file_unique_id):
    return add_value_to_metadata(image, "0th", piexif.ImageIFD.DocumentName, file_unique_id)


def rewrite_metadata(mount_point, object_key, set_function, value):
    image_path = Path("/function/storage", mount_point, object_key)

    image = get_image(image_path)
    metadata = set_function(image, value)
    save_image(image, image_path, metadata)


def get_face_without_name():
    for image_path in Path("/function/storage", FACES_MOUNT_POINT).iterdir():
        with Image.open(image_path) as image:
            image.load()

        if not get_name(image):
            return image_path.name


def get_face_by_tg_file_unique_id(file_unique_id):
    for image_path in Path("/function/storage", FACES_MOUNT_POINT).iterdir():
        with Image.open(image_path) as image:
            image.load()

        if get_tg_file_unique_id(image) == file_unique_id:
            return image_path.name


def get_originals_by_name(name):
    originals = []

    for image_path in Path("/function/storage", FACES_MOUNT_POINT).iterdir():
        with Image.open(image_path) as image:
            image.load()

        if get_name(image) == name:
            originals.append(get_original_path(image))

    return originals
