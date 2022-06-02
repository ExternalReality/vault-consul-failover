locals {
  vpc_region_primary            = "us-west-2"
  vpc_region_secondary          = "us-east-1"
  hvn_region_primary            = "us-west-2"
  hvn_region_secondary          = "us-east-1"  
  cluster_id_primary            = "primary"
  cluster_id_secondary          = "secondary"
  hvn_id_primary                = "us-west-2"
  hvn_id_secondary              = "us-east-1"
}



terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.43"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = ">= 0.18.0"
    }
  }
}

provider "aws" {
  region = local.vpc_region_primary
  assume_role {
    role_arn = "<add arn of assume role>"
  }
}

provider "aws" {
  alias = "us_east_1"
  region = local.vpc_region_secondary
  assume_role {
    role_arn = "<add arn of assume role>"
  }
}

provider "consul" {
  address    = hcp_consul_cluster.main.consul_public_endpoint_url
  datacenter = hcp_consul_cluster.main.datacenter
  token      = hcp_consul_cluster_root_token.token.secret_id
}


resource "hcp_hvn" "main" {
  hvn_id         = local.hvn_id_primary
  cloud_provider = "aws"
  region         = local.hvn_region_primary
  cidr_block     = "172.25.32.0/20"
}

resource "hcp_hvn" "secondary" {
  hvn_id         = local.hvn_id_secondary
  cloud_provider = "aws"
  region         = local.hvn_region_secondary
  cidr_block     = "172.26.32.0/20"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "main"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

module "secondary_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  providers = {
    aws = aws.us_east_1
  }

  name = "secondary"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

module "aws_hcp_consul" {
  source  = "hashicorp/hcp-consul/aws"
  version = "~> 0.7.0"

  hvn             = hcp_hvn.main
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnets
  route_table_ids = module.vpc.public_route_table_ids
}

module "aws_hcp_consul_secondary" {
  source  = "hashicorp/hcp-consul/aws"
  version = "~> 0.7.0"

  providers = {
    aws = aws.us_east_1
  }

  hvn             = hcp_hvn.secondary
  vpc_id          = module.secondary_vpc.vpc_id
  subnet_ids      = module.secondary_vpc.public_subnets
  route_table_ids = module.secondary_vpc.public_route_table_ids
}

resource "hcp_consul_cluster" "main" {
  cluster_id      = local.cluster_id_primary
  hvn_id          = hcp_hvn.main.hvn_id
  public_endpoint = true
  tier            = "development"
}

resource "hcp_consul_cluster" "secondary" {
  cluster_id      = local.cluster_id_secondary
  hvn_id          = hcp_hvn.secondary.hvn_id
  public_endpoint = true
  tier            = "development"
  primary_link = hcp_consul_cluster.main.self_link
  auto_hvn_to_hvn_peering = true
}

resource "hcp_consul_cluster_root_token" "token" {
  cluster_id = hcp_consul_cluster.main.id
}

module "aws_ec2_consul_client" {
  source  = "./hcp-vault-ec2-client/"

  subnet_id                = module.vpc.public_subnets[0]
  security_group_id        = module.aws_hcp_consul.security_group_id
  allowed_ssh_cidr_blocks  = ["0.0.0.0/0"]
  allowed_http_cidr_blocks = ["0.0.0.0/0"]
  client_config_file       = hcp_consul_cluster.main.consul_config_file
  client_ca_file           = hcp_consul_cluster.main.consul_ca_file
  root_token               = hcp_consul_cluster_root_token.token.secret_id
  consul_version           = hcp_consul_cluster.main.consul_version
}

module "aws_ec2_consul_client_secondary" {
  source  = "./hcp-vault-ec2-client/"

  providers = {
    aws = aws.us_east_1
  }

  subnet_id                = module.secondary_vpc.public_subnets[0]
  security_group_id        = module.aws_hcp_consul_secondary.security_group_id
  allowed_ssh_cidr_blocks  = ["0.0.0.0/0"]
  allowed_http_cidr_blocks = ["0.0.0.0/0"]
  client_config_file       = hcp_consul_cluster.secondary.consul_config_file
  client_ca_file           = hcp_consul_cluster.secondary.consul_ca_file
  root_token               = hcp_consul_cluster_root_token.token.secret_id
  consul_version           = hcp_consul_cluster.secondary.consul_version
}

output "consul_root_token" {
  value     = hcp_consul_cluster_root_token.token.secret_id
  sensitive = true
}

output "consul_url" {
  value = hcp_consul_cluster.main.public_endpoint ? (
    hcp_consul_cluster.main.consul_public_endpoint_url
    ) : (
    hcp_consul_cluster.main.consul_private_endpoint_url
  )
}