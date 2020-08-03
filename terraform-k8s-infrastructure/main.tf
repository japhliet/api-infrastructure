# Require TF version to be same as or greater than 0.12.13
terraform {
  required_version = ">=0.12.13"
  backend "s3" {
    region         = "us-east-1"
    key            = "k8s-infrastructure.tfstate"
    dynamodb_table = "aws-locks"
    encrypt        = true
  }
}

# Download any stable version in AWS provider of 2.70.0 or higher in 2.70 train
provider "aws" {
  region  = "us-east-1"
  version = "~> 2.70.0"
}

# kubernetes provider
provider "kubernetes" {
  version = "~> 1.12.0"
}

# kubectl provider
# v1.6.1
provider "kubectl" {
}

//module "k8s_core_services" {
//  source               = "./modules/k8s_core_services"
//}

data "aws_eks_cluster" "rw_api" {
  name = "${replace(local.project, " ", "-")}-k8s-cluster-${var.environment}"
}

data "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
}

module "k8s_infrastructure" {
  source           = "./modules/k8s_infrastructure"
  cluster_endpoint = "${data.aws_eks_cluster.rw_api.endpoint}:4433"
  cluster_ca       = data.aws_eks_cluster.rw_api.certificate_authority.0.data
  cluster_name     = data.aws_eks_cluster.rw_api.name
  aws_region       = var.aws_region
  vpc_id           = data.aws_vpc.eks_vpc.id
}

module "k8s_data_layer" {
  source           = "./modules/k8s_data_layer"
  cluster_endpoint = "${data.aws_eks_cluster.rw_api.endpoint}:4433"
  cluster_ca       = data.aws_eks_cluster.rw_api.certificate_authority.0.data
  cluster_name     = data.aws_eks_cluster.rw_api.name
  aws_region       = var.aws_region
  vpc_id           = data.aws_vpc.eks_vpc.id
}

module "k8s_namespaces" {
  source           = "./modules/k8s_namespaces"
}