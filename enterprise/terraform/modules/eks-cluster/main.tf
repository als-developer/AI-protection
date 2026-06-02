# EKS Cluster Module for BioShield Production

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.cluster_version
  
  vpc_config {
    subnet_ids              = module.vpc.private_subnets
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }
  
  kubernetes_network_config {
    service_ipv4_cidr = "172.20.0.0/16"
    ip_family         = "ipv4"
  }
  
  tags = {
    Environment = var.environment
    Application = "bioshield"
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"
  
  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr
  
  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = cidrsubnets(var.vpc_cidr, 4, 4, 4)
  public_subnets  = cidrsubnets(var.vpc_cidr, 4, 4, 4)
  
  enable_nat_gateway     = true
  single_nat_gateway     = false
  enable_dns_hostnames   = true
  enable_dns_support     = true
  
  tags = {
    Environment = var.environment
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = module.vpc.private_subnets
  
  scaling_config {
    desired_size = var.desired_nodes
    max_size     = var.max_nodes
    min_size     = var.min_nodes
  }
  
  instance_types = var.node_instance_types
  
  capacity_type  = "ON_DEMAND"
  
  taint {
    key    = "dedicated"
    value  = "bioshield"
    effect = "NO_SCHEDULE"
  }
  
  update_config {
    max_unavailable = 1
  }
  
  tags = {
    Environment = var.environment
    NodeGroup   = "bioshield-compute"
  }
}
