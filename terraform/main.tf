terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    telegram = {
      source  = "yi-jiayu/telegram"
      version = "0.3.1"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = "ru-central1-a"
  service_account_key_file = pathexpand(var.sa_key_file_path)
}

provider "telegram" {
  bot_token = var.tg_bot_key
}


resource "yandex_function" "bot" {
  name               = var.bot_function
  entrypoint         = "index.handler"
  memory             = "128"
  runtime            = "python312"
  user_hash          = data.archive_file.bot_source.output_sha512
  service_account_id = yandex_iam_service_account.sa_bot.id
  environment = {
    TELEGRAM_BOT_TOKEN = var.tg_bot_key
    PHOTOS_MOUNT_POINT = yandex_storage_bucket.photos_bucket.bucket
    FACES_MOUNT_POINT  = yandex_storage_bucket.faces_bucket.bucket
    API_GATEWAY_URL    = "https://${yandex_api_gateway.api_gw.domain}"
  }
  #zip архив
  content {
    zip_filename = data.archive_file.bot_source.output_path
  }
  mounts {
    name = yandex_storage_bucket.photos_bucket.bucket
    mode = "ro"
    object_storage {
      bucket = yandex_storage_bucket.photos_bucket.bucket
    }
  }
  mounts {
    name = yandex_storage_bucket.faces_bucket.bucket
    mode = "rw"
    object_storage {
      bucket = yandex_storage_bucket.faces_bucket.bucket
    }
  }
}

resource "yandex_function_iam_binding" "exam_solver_tg_bot_iam" {
  function_id = yandex_function.bot.id
  role        = "functions.functionInvoker"
  members = [
    "system:allUsers",
  ]
}

resource "telegram_bot_webhook" "exam_solver_tg_bot_webhook" {
  url = "https://functions.yandexcloud.net/${yandex_function.bot.id}"
}

resource "yandex_api_gateway" "api_gw" {
  name = var.api_gateway
  spec = <<-EOT
openapi: "3.0.0"
info:
  version: 1.0.0
  title: Photo Face Detector API
paths:
  /:
    get:
      summary: Serve face images from Yandex Cloud Object Storage
      parameters:
        - name: face
          in: query
          required: true
          schema:
            type: string
      x-yc-apigateway-integration:
        type: object_storage
        bucket: ${yandex_storage_bucket.faces_bucket.bucket}
        object: "{face}"
        service_account_id: ${yandex_iam_service_account.sa_bot.id}
EOT
}
#zip архив
data "archive_file" "bot_source" {
  type        = "zip"
  source_dir  = "../src/telegram-bot"
  output_path = "../All_Archives/telegram-bot.zip"
}

resource "yandex_iam_service_account" "sa_bot" {
  name = var.sa_bot
}

resource "yandex_resourcemanager_folder_iam_member" "sa_bot_storage_editor_iam" {
  folder_id = var.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa_bot.id}"
}
resource "yandex_storage_bucket" "faces_bucket" {
  bucket = var.faces_bucket
}

resource "yandex_function" "cropper" {
  name               = var.face_cut_function
  entrypoint         = "index.handler"
  memory             = "128"
  runtime            = "python312"
  user_hash          = data.archive_file.cropper_source.output_sha512
  service_account_id = yandex_iam_service_account.sa_cropper.id
  environment = {
    PHOTOS_MOUNT_POINT = yandex_storage_bucket.photos_bucket.bucket
    FACES_MOUNT_POINT  = yandex_storage_bucket.faces_bucket.bucket
    ACCESS_KEY_ID      = yandex_iam_service_account_static_access_key.sa_cropper_static_key.access_key
    SECRET_ACCESS_KEY  = yandex_iam_service_account_static_access_key.sa_cropper_static_key.secret_key
  }
  #zip архив
  content {
    zip_filename = data.archive_file.cropper_source.output_path
  }
  mounts {
    name = yandex_storage_bucket.photos_bucket.bucket
    mode = "ro"
    object_storage {
      bucket = yandex_storage_bucket.photos_bucket.bucket
    }
  }
  mounts {
    name = yandex_storage_bucket.faces_bucket.bucket
    mode = "rw"
    object_storage {
      bucket = yandex_storage_bucket.faces_bucket.bucket
    }
  }
}

resource "yandex_function_trigger" "crop_tasks_queue_trigger" {
  name = var.face_cut_trigger
  function {
    id                 = yandex_function.cropper.id
    service_account_id = yandex_iam_service_account.sa_cropper.id
  }
  message_queue {
    batch_cutoff       = "0"
    batch_size         = "1"
    queue_id           = yandex_message_queue.crop_tasks_queue.arn
    service_account_id = yandex_iam_service_account.sa_cropper.id
  }
}
#zip архив
data "archive_file" "cropper_source" {
  type        = "zip"
  source_dir  = "../src/face-cut"
  output_path = "../All_Archives/face-cut.zip"
}

resource "yandex_iam_service_account" "sa_cropper" {
  name = var.sa_face_cut
}

resource "yandex_resourcemanager_folder_iam_member" "sa_cropper_function_invoker_role" {
  folder_id = var.folder_id
  role      = "functions.functionInvoker"
  member    = "serviceAccount:${yandex_iam_service_account.sa_cropper.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "sa_cropper_storage_editor_iam" {
  folder_id = var.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa_cropper.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "sa_cropper_ymq_reader_iam" {
  folder_id = var.folder_id
  role      = "ymq.reader"
  member    = "serviceAccount:${yandex_iam_service_account.sa_cropper.id}"
}

resource "yandex_iam_service_account_static_access_key" "sa_cropper_static_key" {
  service_account_id = yandex_iam_service_account.sa_cropper.id
}
resource "yandex_storage_bucket" "photos_bucket" {
  bucket = var.photos_bucket
}

resource "yandex_function" "recognizer" {
  name               = var.face_detection_function
  entrypoint         = "index.handler"
  memory             = "256"
  runtime            = "python312"
  user_hash          = data.archive_file.recognizer_source.output_sha512
  service_account_id = yandex_iam_service_account.sa_recognizer.id
  environment = {
    MOUNT_POINT       = yandex_storage_bucket.photos_bucket.bucket
    QUEUE_URL         = yandex_message_queue.crop_tasks_queue.id
    ACCESS_KEY_ID     = yandex_iam_service_account_static_access_key.sa_recognizer_static_key.access_key
    SECRET_ACCESS_KEY = yandex_iam_service_account_static_access_key.sa_recognizer_static_key.secret_key
  }
  #zip архив
  content {
    zip_filename = data.archive_file.recognizer_source.output_path
  }
  mounts {
    name = yandex_storage_bucket.photos_bucket.bucket
    mode = "ro"
    object_storage {
      bucket = yandex_storage_bucket.photos_bucket.bucket
    }
  }
}

resource "yandex_function_trigger" "photos_bucket_trigger" {
  name = var.face_detection_trigger
  function {
    id                 = yandex_function.recognizer.id
    service_account_id = yandex_iam_service_account.sa_recognizer.id
  }
  object_storage {
    bucket_id    = yandex_storage_bucket.photos_bucket.id
    suffix       = ".jpg"
    create       = true
    batch_cutoff = "0"
  }
}

resource "yandex_message_queue" "crop_tasks_queue" {
  name       = var.face_cut_queue
  access_key = yandex_iam_service_account_static_access_key.sa_recognizer_static_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa_recognizer_static_key.secret_key
}

#zip архив
data "archive_file" "recognizer_source" {
  type        = "zip"
  source_dir  = "../src/face-detection"
  output_path = "../All_Archives/face-detection.zip"
}
resource "yandex_iam_service_account" "sa_recognizer" {
  name = var.sa_face_detection
}

resource "yandex_resourcemanager_folder_iam_member" "sa_recognizer_function_invoker_role" {
  folder_id = var.folder_id
  role      = "functions.functionInvoker"
  member    = "serviceAccount:${yandex_iam_service_account.sa_recognizer.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "sa_recognizer_storage_viewer_iam" {
  folder_id = var.folder_id
  role      = "storage.viewer"
  member    = "serviceAccount:${yandex_iam_service_account.sa_recognizer.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "sa_recognizer_ymq_writer_iam" {
  folder_id = var.folder_id
  role      = "ymq.writer"
  member    = "serviceAccount:${yandex_iam_service_account.sa_recognizer.id}"
}

resource "yandex_iam_service_account_static_access_key" "sa_recognizer_static_key" {
  service_account_id = yandex_iam_service_account.sa_recognizer.id
}
