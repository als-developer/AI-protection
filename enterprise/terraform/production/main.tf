# Sovereign Bio-Shield Ultimate - Production Infrastructure
# AWS Multi-Region Deployment

terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket         = "bioshield-terraform-state-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "bioshield-terraform-locks"
  }
}

provider "aws" {
  region = var.primary_region
  alias  = "primary"
}

provider "aws" {
  region = var.secondary_region
  alias  = "secondary"
}

# Primary Region Resources
module "primary_cluster" {
  source = "../../modules/eks-cluster"
  providers = { aws = aws.primary }
  
  cluster_name     = "bioshield-prod-primary"
  cluster_version  = "1.28"
  vpc_cidr         = "10.0.0.0/16"
  environment      = "production"
  node_instance_types = ["c6i.4xlarge"]
  min_nodes        = 3
  max_nodes        = 30
  desired_nodes    = 5
}

# Secondary Region (DR)
module "secondary_cluster" {
  source = "../../modules/eks-cluster"
  providers = { aws = aws.secondary }
  
  cluster_name     = "bioshield-prod-secondary"
  cluster_version  = "1.28"
  vpc_cidr         = "10.1.0.0/16"
  environment      = "production"
  node_instance_types = ["c6i.4xlarge"]
  min_nodes        = 2
  max_nodes        = 20
  desired_nodes    = 3
}

# Global Database
resource "aws_rds_global_cluster" "bioshield" {
  global_cluster_identifier = "bioshield-global"
  source_db_cluster_identifier = module.primary_cluster.db_cluster_arn
}

# Global Cache (ElastiCache Global Datastore)
resource "aws_elasticache_global_replication_group" "redis" {
  global_replication_group_id_suffix = "bioshield-global-redis"
  primary_replication_group_id = module.primary_cluster.redis_replication_group_id
}

# CloudFront Distribution for API
resource "aws_cloudfront_distribution" "api" {
  enabled = true
  aliases = ["api.bioshield.secure-bank.internal"]
  
  origin {
    domain_name = module.primary_cluster.alb_dns_name
    origin_id   = "primary-api"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "primary-api"
    
    forwarded_values {
      query_string = true
      headers      = ["Authorization", "X-BioShield-Token"]
      cookies {
        forward = "none"
      }
    }
    
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.api.arn
    ssl_support_method  = "sni-only"
  }
}

# Global Accelerator for lowest latency
resource "aws_globalaccelerator_accelerator" "bioshield" {
  name            = "bioshield-global"
  ip_address_type = "IPV4"
  enabled         = true
}

# WAF Web ACL
resource "aws_wafv2_web_acl" "bioshield" {
  name        = "bioshield-waf-prod"
  scope       = "CLOUDFRONT"
  
  default_action {
    allow {}
  }
  
  rule {
    name     = "RateLimit"
    priority = 1
    
    action {
      block {}
    }
    
    statement {
      rate_based_statement {
        limit              = 10000
        aggregate_key_type = "IP"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name               = "RateLimitRule"
      sampled_requests_enabled  = true
    }
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name               = "BioShieldWAF"
    sampled_requests_enabled  = true
  }
}
