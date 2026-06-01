output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "db_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.db.db_instance_endpoint
}

output "redis_endpoint" {
  description = "Redis endpoint"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "backup_bucket_name" {
  description = "S3 backup bucket name"
  value       = aws_s3_bucket.backups.id
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}
