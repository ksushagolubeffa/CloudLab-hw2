from pathlib import Path

from services.cv import recognize_faces
from services.yandex_cloud import send_message_to_queue
from settings import MOUNT_POINT


def handler(event, context):
    object_key = event["messages"][0]["details"]["object_id"]

    faces = recognize_faces(Path("/function/storage", MOUNT_POINT, object_key))
    for face in faces:
        send_message_to_queue({
            "object_key": object_key,
            "rectangle": face,
        })

    return {
        "statusCode": 200,
    }
