data "aws_caller_identity" "current" {}

provider "aws" {
  region = var.region
}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  current_date = formatdate("YYYYMMDD", timestamp())
}

# Crear bucket datalake
resource "null_resource" "create_datalake_graph_bucket" {
  provisioner "local-exec" {
    command = "aws s3api create-bucket --bucket ${var.datalake_graph_bucket_name} --region ${var.region} && ping -n 6 127.0.0.1 >nul"
  }
}

# Crear carpeta "events"
resource "null_resource" "create_datalake_graph_events_folder" {
  provisioner "local-exec" {
    command = "aws s3api put-object --bucket ${var.datalake_graph_bucket_name} --key events/"
  }
  depends_on = [null_resource.create_datalake_graph_bucket]
}

# Crear carpeta con la fecha actual
resource "null_resource" "create_datalake_graph_date_folder" {
  provisioner "local-exec" {
    command = "aws s3api put-object --bucket ${var.datalake_graph_bucket_name} --key ${local.current_date}/"
  }
  depends_on = [null_resource.create_datalake_graph_bucket]
}

# Crear cola SQS para "events"
resource "null_resource" "create_datalake_graph_events_queue" {
  provisioner "local-exec" {
    command = "aws sqs create-queue --queue-name ${var.datalake_graph_bucket_name}-events-queue --region ${var.region} && ping -n 6 127.0.0.1 >nul"
  }
  depends_on = [null_resource.create_datalake_graph_bucket]
}

# Crear cola SQS para la carpeta de la fecha actual
resource "null_resource" "create_datalake_graph_date_queue" {
  provisioner "local-exec" {
    command = "aws sqs create-queue --queue-name ${var.datalake_graph_bucket_name}-${local.current_date}-queue --region ${var.region} && ping -n 6 127.0.0.1 >nul"
  }
  depends_on = [null_resource.create_datalake_graph_bucket]
}

# Crear política de SQS para la cola "events"
resource "aws_sqs_queue_policy" "datalake_graph_events_policy" {
  queue_url = "https://sqs.${var.region}.amazonaws.com/${local.account_id}/${var.datalake_graph_bucket_name}-events-queue"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action    = "SQS:SendMessage"
        Resource  = "arn:aws:sqs:${var.region}:${local.account_id}:${var.datalake_graph_bucket_name}-events-queue"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.datalake_graph_bucket_name}"
          }
        }
      }
    ]
  })
  depends_on = [null_resource.create_datalake_graph_events_queue]
}

# Crear política de SQS para la cola de la fecha actual
resource "aws_sqs_queue_policy" "datalake_graph_date_policy" {
  queue_url = "https://sqs.${var.region}.amazonaws.com/${local.account_id}/${var.datalake_graph_bucket_name}-${local.current_date}-queue"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action    = "SQS:SendMessage"
        Resource  = "arn:aws:sqs:${var.region}:${local.account_id}:${var.datalake_graph_bucket_name}-${local.current_date}-queue"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.datalake_graph_bucket_name}"
          }
        }
      }
    ]
  })
  depends_on = [null_resource.create_datalake_graph_date_queue]
}

resource "aws_s3_bucket_notification" "datalake_graph_notifications" {
  bucket = var.datalake_graph_bucket_name

  queue {
    id             = "events-notification"
    queue_arn      = "arn:aws:sqs:${var.region}:${local.account_id}:${var.datalake_graph_bucket_name}-events-queue"
    events         = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*", "s3:ObjectRestore:*"]
    filter_prefix  = "events/"
  }

  queue {
    id             = "date-notification"
    queue_arn      = "arn:aws:sqs:${var.region}:${local.account_id}:${var.datalake_graph_bucket_name}-${local.current_date}-queue"
    events         = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*", "s3:ObjectRestore:*"]
    filter_prefix  = "${local.current_date}/"
  }
  depends_on = [aws_sqs_queue_policy.datalake_graph_date_policy, aws_sqs_queue_policy.datalake_graph_events_policy]
}

# Eliminar mensajes iniciales en las colas
resource "null_resource" "clear_events_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs purge-queue --queue-url https://sqs.${var.region}.amazonaws.com/${local.account_id}/${var.datalake_graph_bucket_name}-events-queue
    EOT
  }
  depends_on = [aws_s3_bucket_notification.datalake_graph_notifications]
}

resource "null_resource" "clear_date_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs purge-queue --queue-url https://sqs.${var.region}.amazonaws.com/${local.account_id}/${var.datalake_graph_bucket_name}-${local.current_date}-queue
    EOT
  }
  depends_on = [aws_s3_bucket_notification.datalake_graph_notifications]
}


# Datamart-dictionary-ulpgc3
resource "null_resource" "create_datamart_dictionary_bucket" {
  provisioner "local-exec" {
    command = <<EOT
      aws s3api create-bucket --bucket ${var.datamart_dictionary_bucket_name} --region us-east-1
      ping -n 5 127.0.0.1 >nul
    EOT
  }
  depends_on = [null_resource.clear_events_queue, null_resource.clear_date_queue]
}

resource "null_resource" "create_datamart_dictionary_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs create-queue --queue-name ${var.datamart_dictionary_bucket_name}-queue --region us-east-1
      ping -n 5 127.0.0.1 >nul
    EOT
  }
  depends_on = [null_resource.create_datamart_dictionary_bucket]
}

# Datamart_dictionary_bucket
resource "aws_sqs_queue_policy" "datamart_dictionary_policy" {
  queue_url = "https://sqs.us-east-1.amazonaws.com/${data.aws_caller_identity.current.account_id}/${var.datamart_dictionary_bucket_name}-queue"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action    = "SQS:SendMessage"
        Resource  = "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:${var.datamart_dictionary_bucket_name}-queue"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.datamart_dictionary_bucket_name}"
          }
        }
      }
    ]
  })
  depends_on = [null_resource.create_datamart_dictionary_queue]
}


resource "aws_s3_bucket_notification" "datamart_dictionary_notifications" {
  bucket = "${var.datamart_dictionary_bucket_name}"

  queue {
    id        = "notification-datamart-dictionary"
    queue_arn = "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:${var.datamart_dictionary_bucket_name}-queue"
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*", "s3:ObjectRestore:*"]
  }
  depends_on = [aws_sqs_queue_policy.datamart_dictionary_policy]
}


resource "null_resource" "clear_datamart_dictionary_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs purge-queue --queue-url https://sqs.us-east-1.amazonaws.com/${data.aws_caller_identity.current.account_id}/${var.datamart_dictionary_bucket_name}-queue
    EOT
  }
  depends_on = [aws_s3_bucket_notification.datamart_dictionary_notifications]
}


# Datamart_graph_bucket
resource "null_resource" "create_datamart_graph_bucket" {
  provisioner "local-exec" {
    command = <<EOT
      aws s3api create-bucket --bucket ${var.datamart_graph_bucket_name} --region us-east-1
      ping -n 5 127.0.0.1 >nul
    EOT
  }
  depends_on = [null_resource.clear_datamart_dictionary_queue]
}

resource "null_resource" "create_datamart_graph_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs create-queue --queue-name ${var.datamart_graph_bucket_name}-queue --region us-east-1
      ping -n 5 127.0.0.1 >nul
    EOT
  }
  depends_on = [null_resource.create_datamart_graph_bucket]
}

# Datamart_graph_bucket
resource "aws_sqs_queue_policy" "datamart_graph_policy" {
  queue_url = "https://sqs.us-east-1.amazonaws.com/${data.aws_caller_identity.current.account_id}/${var.datamart_graph_bucket_name}-queue"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action    = "SQS:SendMessage"
        Resource  = "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:${var.datamart_graph_bucket_name}-queue"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.datamart_graph_bucket_name}"
          }
        }
      }
    ]
  })
  depends_on = [null_resource.create_datamart_graph_queue]
}

resource "aws_s3_bucket_notification" "datamart_graph_notifications" {
  bucket = "${var.datamart_graph_bucket_name}"

  queue {
    id        = "notification-datamart-graph"
    queue_arn = "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:${var.datamart_graph_bucket_name}-queue"
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*", "s3:ObjectRestore:*"]
  }
  depends_on = [aws_sqs_queue_policy.datamart_graph_policy]
}

resource "null_resource" "clear_datamart_graph_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs purge-queue --queue-url https://sqs.us-east-1.amazonaws.com/${data.aws_caller_identity.current.account_id}/${var.datamart_graph_bucket_name}-queue
    EOT
  }
  depends_on = [aws_s3_bucket_notification.datamart_graph_notifications]
}

# Datamart_stats_bucket
resource "null_resource" "create_datamart_stats_bucket" {
  provisioner "local-exec" {
    command = <<EOT
      aws s3api create-bucket --bucket ${var.datamart_stats_bucket_name} --region us-east-1
      ping -n 5 127.0.0.1 >nul
    EOT
  }
  depends_on = [null_resource.clear_datamart_graph_queue]
}

resource "null_resource" "create_datamart_stats_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs create-queue --queue-name ${var.datamart_stats_bucket_name}-queue --region us-east-1
      ping -n 5 127.0.0.1 >nul
    EOT
  }
  depends_on = [null_resource.create_datamart_stats_bucket]
}

# Datamart_stats_bucket
resource "aws_sqs_queue_policy" "datamart_stats_policy" {
  queue_url = "https://sqs.us-east-1.amazonaws.com/${data.aws_caller_identity.current.account_id}/${var.datamart_stats_bucket_name}-queue"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action    = "SQS:SendMessage"
        Resource  = "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:${var.datamart_stats_bucket_name}-queue"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.datamart_stats_bucket_name}"
          }
        }
      }
    ]
  })
  depends_on = [null_resource.create_datamart_stats_queue]
}


resource "aws_s3_bucket_notification" "datamart_stats_notifications" {
  bucket = "${var.datamart_stats_bucket_name}"

  queue {
    id        = "notification-datamart-stats"
    queue_arn = "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:${var.datamart_stats_bucket_name}-queue"
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*", "s3:ObjectRestore:*"]
  }
  depends_on = [aws_sqs_queue_policy.datamart_stats_policy]
}

resource "null_resource" "clear_datamart_stats_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs purge-queue --queue-url https://sqs.us-east-1.amazonaws.com/${data.aws_caller_identity.current.account_id}/${var.datamart_stats_bucket_name}-queue
    EOT
  }
  depends_on = [aws_s3_bucket_notification.datamart_stats_notifications]
}

# Crear bucket de código
resource "null_resource" "create_code_bucket" {
  provisioner "local-exec" {
    command = "aws s3api create-bucket --bucket ${var.code_bucket_name} --region us-east-1 && ping -n 5 127.0.0.1 >nul"
  }
  depends_on = [null_resource.clear_datamart_stats_queue]
}

# Subir archivos .py al bucket de código
resource "aws_s3_object" "code_files" {
  for_each = toset([
    "data-processing/crawler.py",
    "data-processing/dictionary-builder.py",
    "graph-management/graph-builder.py",
    "graph-management/graph-query.py",
    "statistics/stat-builder.py",
    "statistics/stat-query.py"
  ])

  bucket = "${var.code_bucket_name}"
  key    = basename(each.value)
  source = "${path.root}/../graphword/src/main/services/${each.value}"

  depends_on = [null_resource.create_code_bucket]
}