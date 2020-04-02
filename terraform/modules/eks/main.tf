#
# EKS resources
#
resource "aws_eks_cluster" "eks_cluster" {
  name     = "${replace(var.project, " ", "-")}-k8s-cluster-${var.environment}"
  role_arn = aws_iam_role.eks-cluster-admin.arn

  vpc_config {
    subnet_ids         = var.subnet_ids # At the time of this writing, AWS wasn't accepting EKS on us-east-1e
    security_group_ids = [aws_security_group.eks_cluster_security_group.id]
    endpoint_private_access = true
    endpoint_public_access = false
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks-admin-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks-admin-AmazonEKSServicePolicy,
  ]
}

resource "aws_security_group" "eks_cluster_security_group" {
  name        = "${replace(var.project, " ", "-")}eks-cluster-security-group"
  description = "Cluster communication with worker nodes"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${replace(var.project, " ", "-")}-k8s-cluster-security-group"
  }
}

resource "aws_security_group_rule" "eks_cluster_cluster_ingress_workstation_https" {
  cidr_blocks       = ["0.0.0.0/0"] # TODO: restrict for improved security
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_cluster_security_group.id
  to_port           = 443
  type              = "ingress"
}

resource "aws_iam_role" "eks-cluster-admin" {
  name = "${replace(var.project, " ", "-")}-eks-cluster-admin-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks-admin-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-cluster-admin.name
}

resource "aws_iam_role_policy_attachment" "eks-admin-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks-cluster-admin.name
}

resource "aws_iam_openid_connect_provider" "example" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = []
  url             = aws_eks_cluster.eks_cluster.identity.0.oidc.0.issuer
}

#
# Node Group shared resources
#
resource "aws_iam_role" "eks-node-group-iam-role" {
  name = "eks-node-group-admin"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

data "aws_iam_policy_document" "eks-admin-ALBIngressControllerIAMPolicy-document" {
  source_json = file("${path.module}/alb-ingress-controller-iam-policy.json")
}

resource "aws_iam_policy" "eks-admin-ALBIngressControllerIAMPolicy" {
  name   = "ALBIngressControllerIAMPolicy"
  path   = "/"
  policy = data.aws_iam_policy_document.eks-admin-ALBIngressControllerIAMPolicy-document.json
}

data "aws_iam_policy_document" "eks-admin-ClusterAutoscaleAccessPolicy-document" {
  source_json = file("${path.module}/cluster-autoscale-access-policy.json")
}

resource "aws_iam_policy" "eks-admin-ClusterAutoscaleAccessPolicy" {
  name   = "ClusterAutoscaleAccessPolicy"
  path   = "/"
  policy = data.aws_iam_policy_document.eks-admin-ClusterAutoscaleAccessPolicy-document.json
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy_attachment" "eks-admin-ALBIngressControllerIAMPolicy" {
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/ALBIngressControllerIAMPolicy"
  role       = aws_iam_role.eks-node-group-iam-role.name
}

resource "aws_iam_role_policy_attachment" "eks-admin-ClusterAutoscaleAccessPolicy" {
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/ClusterAutoscaleAccessPolicy"
  role       = aws_iam_role.eks-node-group-iam-role.name
}

resource "aws_iam_role_policy_attachment" "eks-node-group-admin-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks-node-group-iam-role.name
}

resource "aws_iam_role_policy_attachment" "eks-node-group-admin-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks-node-group-iam-role.name
}

resource "aws_iam_role_policy_attachment" "eks-node-group-admin-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-node-group-iam-role.name
}

resource "aws_iam_role_policy_attachment" "eks-node-group-admin-CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.eks-node-group-iam-role.name
}