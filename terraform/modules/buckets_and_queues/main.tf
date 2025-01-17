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
    command = "aws s3api create-bucket --bucket ${var.datalake_bucket} --region ${var.region} && ping -n 6 127.0.0.1 >nul"
  }
}

# Crear carpeta "events"
resource "null_resource" "create_datalake_graph_events_folder" {
  provisioner "local-exec" {
    command = "aws s3api put-object --bucket ${var.datalake_bucket} --key events/"
  }
  depends_on = [null_resource.create_datalake_graph_bucket]
}

# Crear carpeta con la fecha actual
resource "null_resource" "create_datalake_graph_date_folder" {
  provisioner "local-exec" {
    command = "aws s3api put-object --bucket ${var.datalake_bucket} --key ${local.current_date}/"
  }
  depends_on = [null_resource.create_datalake_graph_bucket]
}

# Crear cola SQS para "events"
resource "null_resource" "create_datalake_graph_events_queue" {
  provisioner "local-exec" {
    command = "aws sqs create-queue --queue-name ${var.datalake_bucket}-events-queue --region ${var.region} && ping -n 6 127.0.0.1 >nul"
  }
  depends_on = [null_resource.create_datalake_graph_bucket]
}

# Crear cola SQS para la carpeta de la fecha actual
resource "null_resource" "create_datalake_graph_date_queue" {
  provisioner "local-exec" {
    command = "aws sqs create-queue --queue-name ${var.datalake_bucket}-${local.current_date}-queue --region ${var.region} && ping -n 6 127.0.0.1 >nul"
  }
  depends_on = [null_resource.create_datalake_graph_bucket]
}

# Crear política de SQS para la cola "events"
resource "aws_sqs_queue_policy" "datalake_graph_events_policy" {
  queue_url = "https://sqs.${var.region}.amazonaws.com/${local.account_id}/${var.datalake_bucket}-events-queue"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action    = "SQS:SendMessage"
        Resource  = "arn:aws:sqs:${var.region}:${local.account_id}:${var.datalake_bucket}-events-queue"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.datalake_bucket}"
          }
        }
      }
    ]
  })
  depends_on = [null_resource.create_datalake_graph_events_queue]
}

# Crear política de SQS para la cola de la fecha actual
resource "aws_sqs_queue_policy" "datalake_graph_date_policy" {
  queue_url = "https://sqs.${var.region}.amazonaws.com/${local.account_id}/${var.datalake_bucket}-${local.current_date}-queue"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action    = "SQS:SendMessage"
        Resource  = "arn:aws:sqs:${var.region}:${local.account_id}:${var.datalake_bucket}-${local.current_date}-queue"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.datalake_bucket}"
          }
        }
      }
    ]
  })
  depends_on = [null_resource.create_datalake_graph_date_queue]
}

resource "aws_s3_bucket_notification" "datalake_graph_notifications" {
  bucket = var.datalake_bucket

  queue {
    id             = "events-notification"
    queue_arn      = "arn:aws:sqs:${var.region}:${local.account_id}:${var.datalake_bucket}-events-queue"
    events         = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*", "s3:ObjectRestore:*"]
    filter_prefix  = "events/"
  }

  queue {
    id             = "date-notification"
    queue_arn      = "arn:aws:sqs:${var.region}:${local.account_id}:${var.datalake_bucket}-${local.current_date}-queue"
    events         = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*", "s3:ObjectRestore:*"]
    filter_prefix  = "${local.current_date}/"
  }
  depends_on = [aws_sqs_queue_policy.datalake_graph_date_policy, aws_sqs_queue_policy.datalake_graph_events_policy]
}

# Eliminar mensajes iniciales en las colas
resource "null_resource" "clear_events_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs purge-queue --queue-url https://sqs.${var.region}.amazonaws.com/${local.account_id}/${var.datalake_bucket}-events-queue
    EOT
  }
  depends_on = [aws_s3_bucket_notification.datalake_graph_notifications]
}

resource "null_resource" "clear_date_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs purge-queue --queue-url https://sqs.${var.region}.amazonaws.com/${local.account_id}/${var.datalake_bucket}-${local.current_date}-queue
    EOT
  }
  depends_on = [aws_s3_bucket_notification.datalake_graph_notifications]
}


# Datamart-dictionary-ulpgc4
resource "null_resource" "create_datamart_dictionary_bucket" {
  provisioner "local-exec" {
    command = <<EOT
      aws s3api create-bucket --bucket datamart-dictionary-ulpgc4 --region us-east-1
      ping -n 5 127.0.0.1 >nul
    EOT
  }
  depends_on = [null_resource.clear_events_queue, null_resource.clear_date_queue]
}

resource "null_resource" "create_datamart_dictionary_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs create-queue --queue-name datamart-dictionary-ulpgc4-queue --region us-east-1
      ping -n 5 127.0.0.1 >nul
    EOT
  }
  depends_on = [null_resource.create_datamart_dictionary_bucket]
}

# Datamart-dictionary-ulpgc4
resource "aws_sqs_queue_policy" "datamart_dictionary_policy" {
  queue_url = "https://sqs.us-east-1.amazonaws.com/${data.aws_caller_identity.current.account_id}/datamart-dictionary-ulpgc4-queue"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action    = "SQS:SendMessage"
        Resource  = "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:datamart-dictionary-ulpgc4-queue"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::datamart-dictionary-ulpgc4"
          }
        }
      }
    ]
  })
  depends_on = [null_resource.create_datamart_dictionary_queue]
}


resource "aws_s3_bucket_notification" "datamart_dictionary_notifications" {
  bucket = "datamart-dictionary-ulpgc4"

  queue {
    id        = "notification-datamart-dictionary"
    queue_arn = "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:datamart-dictionary-ulpgc4-queue"
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*", "s3:ObjectRestore:*"]
  }
  depends_on = [aws_sqs_queue_policy.datamart_dictionary_policy]
}


resource "null_resource" "clear_datamart_dictionary_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs purge-queue --queue-url https://sqs.us-east-1.amazonaws.com/${data.aws_caller_identity.current.account_id}/datamart-dictionary-ulpgc4-queue
    EOT
  }
  depends_on = [aws_s3_bucket_notification.datamart_dictionary_notifications]
}


# Datamart-graph-ulpgc4
resource "null_resource" "create_datamart_graph_bucket" {
  provisioner "local-exec" {
    command = <<EOT
      aws s3api create-bucket --bucket datamart-graph-ulpgc4 --region us-east-1
      ping -n 5 127.0.0.1 >nul
    EOT
  }
  depends_on = [null_resource.clear_datamart_dictionary_queue]
}

resource "null_resource" "create_datamart_graph_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs create-queue --queue-name datamart-graph-ulpgc4-queue --region us-east-1
      ping -n 5 127.0.0.1 >nul
    EOT
  }
  depends_on = [null_resource.create_datamart_graph_bucket]
}

# Datamart-graph-ulpgc4
resource "aws_sqs_queue_policy" "datamart_graph_policy" {
  queue_url = "https://sqs.us-east-1.amazonaws.com/${data.aws_caller_identity.current.account_id}/datamart-graph-ulpgc4-queue"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action    = "SQS:SendMessage"
        Resource  = "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:datamart-graph-ulpgc4-queue"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::datamart-graph-ulpgc4"
          }
        }
      }
    ]
  })
  depends_on = [null_resource.create_datamart_graph_queue]
}

resource "aws_s3_bucket_notification" "datamart_graph_notifications" {
  bucket = "datamart-graph-ulpgc4"

  queue {
    id        = "notification-datamart-graph"
    queue_arn = "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:datamart-graph-ulpgc4-queue"
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*", "s3:ObjectRestore:*"]

  }
  depends_on = [aws_sqs_queue_policy.datamart_graph_policy]
}

resource "null_resource" "clear_datamart_graph_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs purge-queue --queue-url https://sqs.us-east-1.amazonaws.com/${data.aws_caller_identity.current.account_id}/datamart-graph-ulpgc4-queue
    EOT
  }
  depends_on = [aws_s3_bucket_notification.datamart_graph_notifications]
}

# Datamart-stats-ulpgc4
resource "null_resource" "create_datamart_stats_bucket" {
  provisioner "local-exec" {
    command = <<EOT
      aws s3api create-bucket --bucket datamart-stats-ulpgc4 --region us-east-1
      ping -n 5 127.0.0.1 >nul
    EOT
  }
  depends_on = [null_resource.clear_datamart_graph_queue]
}

resource "null_resource" "create_datamart_stats_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs create-queue --queue-name datamart-stats-ulpgc4-queue --region us-east-1
      ping -n 5 127.0.0.1 >nul
    EOT
  }
  depends_on = [null_resource.create_datamart_stats_bucket]
}

# Datamart-stats-ulpgc4
resource "aws_sqs_queue_policy" "datamart_stats_policy" {
  queue_url = "https://sqs.us-east-1.amazonaws.com/${data.aws_caller_identity.current.account_id}/datamart-stats-ulpgc4-queue"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action    = "SQS:SendMessage"
        Resource  = "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:datamart-stats-ulpgc4-queue"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::datamart-stats-ulpgc4"
          }
        }
      }
    ]
  })
  depends_on = [null_resource.create_datamart_stats_queue]
}


resource "aws_s3_bucket_notification" "datamart_stats_notifications" {
  bucket = "datamart-stats-ulpgc4"

  queue {
    id        = "notification-datamart-stats"
    queue_arn = "arn:aws:sqs:us-east-1:${data.aws_caller_identity.current.account_id}:datamart-stats-ulpgc4-queue"
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*", "s3:ObjectRestore:*"]
  }
  depends_on = [aws_sqs_queue_policy.datamart_stats_policy]
}

resource "null_resource" "clear_datamart_stats_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs purge-queue --queue-url https://sqs.us-east-1.amazonaws.com/${data.aws_caller_identity.current.account_id}/datamart-stats-ulpgc4-queue
    EOT
  }
  depends_on = [aws_s3_bucket_notification.datamart_stats_notifications]
}

# Crear bucket de código
resource "null_resource" "create_code_bucket" {
  provisioner "local-exec" {
    command = "aws s3api create-bucket --bucket graph-code-bucket-ulpgc4 --region us-east-1 && ping -n 5 127.0.0.1 >nul"
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

  bucket = "graph-code-bucket-ulpgc4"
  key    = basename(each.value)
  source = "${path.root}/../graphword/src/main/services/${each.value}"

  depends_on = [null_resource.create_code_bucket]
}