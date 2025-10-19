# modules/security_groups/outputs.tf
output "sg_ids" {
  description = "All security group IDs keyed by name"
  value = {
    admin     = aws_security_group.admin.id
    k8s_nodes = aws_security_group.k8s_nodes.id
    kafka     = aws_security_group.kafka.id
    mongo     = aws_security_group.mongo.id
    processor = aws_security_group.processor.id
    producers = aws_security_group.producers.id
  }
}

# Convenience single-value outputs (handy at the root without map indexing)
output "admin_sg_id" { value = aws_security_group.admin.id }
output "k8s_nodes_sg_id" { value = aws_security_group.k8s_nodes.id }
output "kafka_sg_id" { value = aws_security_group.kafka.id }
output "mongo_sg_id" { value = aws_security_group.mongo.id }
output "processor_sg_id" { value = aws_security_group.processor.id }
output "producers_sg_id" { value = aws_security_group.producers.id }
