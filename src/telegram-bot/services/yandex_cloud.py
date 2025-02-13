import piexif
from PIL import Image

def get_image(image_path):
    with Image.open(image_path) as image:
        image.load()
    return image


def save_image(image, image_path, exif=None):
    if exif:
        image.save(image_path, exif=piexif.dump(exif))
    else:
        image.save(image_path)


def get_image_bytes(image_path):

    with open(image_path, "rb") as image_file:
        return image_file.read()