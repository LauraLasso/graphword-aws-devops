# Bucket con todos las aplicaciones que deben ejecutar las instancias ec2
# Bucket con todos las aplicaciones que deben ejecutar las instancias EC2
resource "aws_s3_bucket" "my_code_bucket" {
  bucket = "my-code-bucket"
  acl    = "private"
}

resource "aws_s3_bucket_object" "upload_py_files" {
  # Encuentra todos los archivos .py en el directorio raíz del proyecto (fuera de la carpeta terraform)
  for_each    = fileset("../", "*.py") # Sube al nivel del proyecto para buscar archivos .py
  bucket      = aws_s3_bucket.my_code_bucket.bucket
  key         = each.value                           # Nombre del archivo en el bucket
  source      = "../${each.value}"    # Ruta completa del archivo encontrado
  content_type = "application/octet-stream"
}


# Datalake y datamarts
resource "aws_s3_bucket" "datalake" {
  bucket = var.datalake_bucket
  acl    = "private"
  lifecycle {
    ignore_changes = [object_lock_configuration]
  }
}

resource "aws_s3_bucket" "datamart_dictionary" {
  bucket = var.datamart_dictionary_bucket
  acl    = "private"
  lifecycle {
    ignore_changes = [object_lock_configuration]
  }
}

resource "aws_s3_bucket" "datamart_graph" {
  bucket = var.datamart_graph_bucket
  acl    = "private"
  lifecycle {
    ignore_changes = [object_lock_configuration]
  }
}

resource "aws_s3_bucket" "datamart_stats" {
  bucket = var.datamart_stats_bucket
  acl    = "private"
  lifecycle {
    ignore_changes = [object_lock_configuration]
  }
}