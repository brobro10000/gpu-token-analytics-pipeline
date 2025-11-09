# modules/security_groups/outputs.tf
output "sg_ids" {
  description = "All security group IDs keyed by name"
  value = {
    admin     = aws_security_group.admin.id
    k8s_nodes = aws_security_group.k8s_nodes.id
    # Conditionally include CA1 SGs if enabled
    kafka     = var.enable_ca1_sgs ? aws_security_group.kafka[0].id : null
    mongo     = var.enable_ca1_sgs ? aws_security_group.mongo[0].id : null
    processor = var.enable_ca1_sgs ? aws_security_group.processor[0].id : null
    producers = var.enable_ca1_sgs ? aws_security_group.producers[0].id : null
  }
}

# Convenience single-value outputs (handy at the root without map indexing)
output "admin_sg_id" {
  description = "Admin SG ID (SSH from your IP)"
  value       = aws_security_group.admin.id
}

output "k8s_nodes_sg_id" {
  description = "Kubernetes (k3s) nodes SG ID"
  value       = aws_security_group.k8s_nodes.id
}

output "kafka_sg_id" {
  description = "Kafka SG ID (only if CA1 SGs enabled)"
  value       = length(aws_security_group.kafka) > 0 ? aws_security_group.kafka[0].id : null
}

output "mongo_sg_id" {
  description = "MongoDB SG ID (only if CA1 SGs enabled)"
  value       = length(aws_security_group.mongo) > 0 ? aws_security_group.mongo[0].id : null
}

output "processor_sg_id" {
  description = "Processor SG ID (only if CA1 SGs enabled)"
  value       = length(aws_security_group.processor) > 0 ? aws_security_group.processor[0].id : null
}

output "producers_sg_id" {
  description = "Producers SG ID (only if CA1 SGs enabled)"
  value       = length(aws_security_group.producers) > 0 ? aws_security_group.producers[0].id : null
}
