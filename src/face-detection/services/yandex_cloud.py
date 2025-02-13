import json

import boto3

from settings import ACCESS_KEY_ID, SECRET_ACCESS_KEY, QUEUE_URL


def get_ymq_client():
    return boto3.client(
        service_name="sqs",
        endpoint_url="https://message-queue.api.cloud.yandex.net",
        region_name="ru-central1",
        aws_access_key_id=ACCESS_KEY_ID,
        aws_secret_access_key=SECRET_ACCESS_KEY,
    )


def send_message_to_queue(message):
    get_ymq_client().send_message(QueueUrl=QUEUE_URL, MessageBody=json.dumps(message))
