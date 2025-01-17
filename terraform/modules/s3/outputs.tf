output "my_code_bucket_name" {
  value = aws_s3_bucket.my_code_bucket.bucket
}

output "datalake_bucket_name" {
  value = aws_s3_bucket.datalake.bucket
}

output "datamart_dictionary_bucket_name" {
  value = aws_s3_bucket.datamart_dictionary.bucket
}

output "datamart_graph_bucket_name" {
  value = aws_s3_bucket.datamart_graph.bucket
}

output "datamart_stats_bucket_name" {
  value = aws_s3_bucket.datamart_stats.bucket
}