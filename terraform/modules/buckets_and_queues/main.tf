data "aws_caller_identity" "current" {}

provider "aws" {
  region = var.region
}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  current_date = formatdate("YYYYMMDD", timestamp())
}

resource "null_resource" "create_datalake_graph_bucket" {
  provisioner "local-exec" {
    command = "aws s3api create-bucket --bucket ${var.datalake_graph_bucket}${var.suffix_number} --region ${var.region}"
  }
}

resource "null_resource" "create_datalake_graph_events_folder" {
  provisioner "local-exec" {
    command = "aws s3api put-object --bucket ${var.datalake_graph_bucket}${var.suffix_number} --key events/"
  }
  depends_on = [null_resource.create_datalake_graph_bucket]
}

resource "null_resource" "create_datalake_graph_date_folder" {
  provisioner "local-exec" {
    command = "aws s3api put-object --bucket ${var.datalake_graph_bucket}${var.suffix_number} --key ${local.current_date}/"
  }
  depends_on = [null_resource.create_datalake_graph_bucket]
}

resource "null_resource" "create_datalake_graph_events_queue" {
  provisioner "local-exec" {
    command = "aws sqs create-queue --queue-name ${var.datalake_graph_bucket}${var.suffix_number}-events-queue --region ${var.region}"
  }
  depends_on = [null_resource.create_datalake_graph_bucket]
}

resource "null_resource" "create_datalake_graph_date_queue" {
  provisioner "local-exec" {
    command = "aws sqs create-queue --queue-name ${var.datalake_graph_bucket}${var.suffix_number}-${local.current_date}-queue --region ${var.region}"
  }
  depends_on = [null_resource.create_datalake_graph_bucket]
}

resource "aws_sqs_queue_policy" "datalake_graph_events_policy" {
  queue_url = "https://sqs.${var.region}.amazonaws.com/${local.account_id}/${var.datalake_graph_bucket}${var.suffix_number}-events-queue"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action    = "SQS:SendMessage"
        Resource  = "arn:aws:sqs:${var.region}:${local.account_id}:${var.datalake_graph_bucket}${var.suffix_number}-events-queue"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.datalake_graph_bucket}${var.suffix_number}"
          }
        }
      }
    ]
  })
  depends_on = [null_resource.create_datalake_graph_events_queue]
}

resource "aws_sqs_queue_policy" "datalake_graph_date_policy" {
  queue_url = "https://sqs.${var.region}.amazonaws.com/${local.account_id}/${var.datalake_graph_bucket}${var.suffix_number}-${local.current_date}-queue"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action    = "SQS:SendMessage"
        Resource  = "arn:aws:sqs:${var.region}:${local.account_id}:${var.datalake_graph_bucket}${var.suffix_number}-${local.current_date}-queue"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.datalake_graph_bucket}${var.suffix_number}"
          }
        }
      }
    ]
  })
  depends_on = [null_resource.create_datalake_graph_date_queue]
}

resource "aws_s3_bucket_notification" "datalake_graph_notifications" {
  bucket = "${var.datalake_graph_bucket}${var.suffix_number}"

  queue {
    id             = "events-notification"
    queue_arn      = "arn:aws:sqs:${var.region}:${local.account_id}:${var.datalake_graph_bucket}${var.suffix_number}-events-queue"
    events         = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*", "s3:ObjectRestore:*"]
    filter_prefix  = "events/"
  }

  queue {
    id             = "date-notification"
    queue_arn      = "arn:aws:sqs:${var.region}:${local.account_id}:${var.datalake_graph_bucket}${var.suffix_number}-${local.current_date}-queue"
    events         = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*", "s3:ObjectRestore:*"]
    filter_prefix  = "${local.current_date}/"
  }
  depends_on = [aws_sqs_queue_policy.datalake_graph_date_policy, aws_sqs_queue_policy.datalake_graph_events_policy]
}

resource "null_resource" "clear_events_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs purge-queue --queue-url https://sqs.${var.region}.amazonaws.com/${local.account_id}/${var.datalake_graph_bucket}${var.suffix_number}-events-queue
    EOT
  }
  depends_on = [aws_s3_bucket_notification.datalake_graph_notifications]
}

resource "null_resource" "clear_date_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs purge-queue --queue-url https://sqs.${var.region}.amazonaws.com/${local.account_id}/${var.datalake_graph_bucket}${var.suffix_number}-${local.current_date}-queue
    EOT
  }
  depends_on = [aws_s3_bucket_notification.datalake_graph_notifications]
}


resource "null_resource" "create_datamart_dictionary_bucket" {
  provisioner "local-exec" {
    command = "aws s3api create-bucket --bucket ${var.datamart_dictionary_bucket}${var.suffix_number} --region ${var.region}"
  }
  depends_on = [null_resource.clear_events_queue, null_resource.clear_date_queue]
}

resource "null_resource" "create_datamart_dictionary_queue" {
  provisioner "local-exec" {
    command = "aws sqs create-queue --queue-name ${var.datamart_dictionary_bucket}${var.suffix_number}-queue --region ${var.region}"
  }
  depends_on = [null_resource.create_datamart_dictionary_bucket]
}

resource "aws_sqs_queue_policy" "datamart_dictionary_policy" {
  queue_url = "https://sqs.${var.region}.amazonaws.com/${data.aws_caller_identity.current.account_id}/${var.datamart_dictionary_bucket}${var.suffix_number}-queue"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action    = "SQS:SendMessage"
        Resource  = "arn:aws:sqs:${var.region}:${data.aws_caller_identity.current.account_id}:${var.datamart_dictionary_bucket}${var.suffix_number}-queue"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.datamart_dictionary_bucket}${var.suffix_number}"
          }
        }
      }
    ]
  })
  depends_on = [null_resource.create_datamart_dictionary_queue]
}


resource "aws_s3_bucket_notification" "datamart_dictionary_notifications" {
  bucket = "${var.datamart_dictionary_bucket}${var.suffix_number}"

  queue {
    id        = "notification-datamart-dictionary"
    queue_arn = "arn:aws:sqs:${var.region}:${data.aws_caller_identity.current.account_id}:${var.datamart_dictionary_bucket}${var.suffix_number}-queue"
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*", "s3:ObjectRestore:*"]
  }
  depends_on = [aws_sqs_queue_policy.datamart_dictionary_policy]
}


resource "null_resource" "clear_datamart_dictionary_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs purge-queue --queue-url https://sqs.${var.region}.amazonaws.com/${data.aws_caller_identity.current.account_id}/${var.datamart_dictionary_bucket}${var.suffix_number}-queue
    EOT
  }
  depends_on = [aws_s3_bucket_notification.datamart_dictionary_notifications]
}


resource "null_resource" "create_datamart_graph_bucket" {
  provisioner "local-exec" {
    command = "aws s3api create-bucket --bucket ${var.datamart_graph_bucket}${var.suffix_number} --region ${var.region}"
  }
  depends_on = [null_resource.clear_datamart_dictionary_queue]
}

resource "null_resource" "create_datamart_graph_queue" {
  provisioner "local-exec" {
    command = "aws sqs create-queue --queue-name ${var.datamart_graph_bucket}${var.suffix_number}-queue --region ${var.region}"
  }
  depends_on = [null_resource.create_datamart_graph_bucket]
}

resource "aws_sqs_queue_policy" "datamart_graph_policy" {
  queue_url = "https://sqs.${var.region}.amazonaws.com/${data.aws_caller_identity.current.account_id}/${var.datamart_graph_bucket}${var.suffix_number}-queue"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action    = "SQS:SendMessage"
        Resource  = "arn:aws:sqs:${var.region}:${data.aws_caller_identity.current.account_id}:${var.datamart_graph_bucket}${var.suffix_number}-queue"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.datamart_graph_bucket}${var.suffix_number}"
          }
        }
      }
    ]
  })
  depends_on = [null_resource.create_datamart_graph_queue]
}

resource "aws_s3_bucket_notification" "datamart_graph_notifications" {
  bucket = "${var.datamart_graph_bucket}${var.suffix_number}"

  queue {
    id        = "notification-datamart-graph"
    queue_arn = "arn:aws:sqs:${var.region}:${data.aws_caller_identity.current.account_id}:${var.datamart_graph_bucket}${var.suffix_number}-queue"
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*", "s3:ObjectRestore:*"]
  }
  depends_on = [aws_sqs_queue_policy.datamart_graph_policy]
}

resource "null_resource" "clear_datamart_graph_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs purge-queue --queue-url https://sqs.${var.region}.amazonaws.com/${data.aws_caller_identity.current.account_id}/${var.datamart_graph_bucket}${var.suffix_number}-queue
    EOT
  }
  depends_on = [aws_s3_bucket_notification.datamart_graph_notifications]
}

resource "null_resource" "create_datamart_stats_bucket" {
  provisioner "local-exec" {
    command = "aws s3api create-bucket --bucket ${var.datamart_stats_bucket}${var.suffix_number} --region ${var.region}"
  }
  depends_on = [null_resource.clear_datamart_graph_queue]
}

resource "null_resource" "create_datamart_stats_queue" {
  provisioner "local-exec" {
    command = "aws sqs create-queue --queue-name ${var.datamart_stats_bucket}${var.suffix_number}-queue --region ${var.region}"
  }
  depends_on = [null_resource.create_datamart_stats_bucket]
}

resource "aws_sqs_queue_policy" "datamart_stats_policy" {
  queue_url = "https://sqs.${var.region}.amazonaws.com/${data.aws_caller_identity.current.account_id}/${var.datamart_stats_bucket}${var.suffix_number}-queue"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action    = "SQS:SendMessage"
        Resource  = "arn:aws:sqs:${var.region}:${data.aws_caller_identity.current.account_id}:${var.datamart_stats_bucket}${var.suffix_number}-queue"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.datamart_stats_bucket}${var.suffix_number}"
          }
        }
      }
    ]
  })
  depends_on = [null_resource.create_datamart_stats_queue]
}


resource "aws_s3_bucket_notification" "datamart_stats_notifications" {
  bucket = "${var.datamart_stats_bucket}${var.suffix_number}"

  queue {
    id        = "notification-datamart-stats"
    queue_arn = "arn:aws:sqs:${var.region}:${data.aws_caller_identity.current.account_id}:${var.datamart_stats_bucket}${var.suffix_number}-queue"
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*", "s3:ObjectRestore:*"]
  }
  depends_on = [aws_sqs_queue_policy.datamart_stats_policy]
}

resource "null_resource" "clear_datamart_stats_queue" {
  provisioner "local-exec" {
    command = <<EOT
      aws sqs purge-queue --queue-url https://sqs.${var.region}.amazonaws.com/${data.aws_caller_identity.current.account_id}/${var.datamart_stats_bucket}${var.suffix_number}-queue
    EOT
  }
  depends_on = [aws_s3_bucket_notification.datamart_stats_notifications]
}

resource "null_resource" "create_code_bucket" {
  provisioner "local-exec" {
    command = "aws s3api create-bucket --bucket ${var.code_bucket}${var.suffix_number} --region ${var.region}"
  }
  depends_on = [null_resource.clear_datamart_stats_queue]
}

resource "aws_s3_object" "code_files" {
  for_each = toset([
    "data-processing/crawler.py",
    "data-processing/dictionary-builder.py",
    "graph-management/graph-builder.py",
    "graph-management/graph-query.py",
    "statistics/stat-builder.py",
    "statistics/stat-query.py"
  ])

  bucket = "${var.code_bucket}${var.suffix_number}"
  key    = basename(each.value)
  source = "${path.root}/../graphword/src/main/services/${each.value}"

  depends_on = [null_resource.create_code_bucket]
}
