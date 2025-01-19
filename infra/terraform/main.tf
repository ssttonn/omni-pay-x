# --- 1. Virtual Private Cloud (VPC) ---
module "vpc" {
  # Use the official AWS VPC module from Terraform Registry
  source = "terraform-aws-modules/vpc/aws"
  # Pin the module version to ensure reproducible infrastructure
  version = "5.1.2"

  # The unique identifier for the VPC in the AWS console
  name = "omnipayx-vpc"

  # Allocate a massive IP range (approx. 65,536 IPs) for the entire system
  cidr = "10.0.0.0/16"

  # Distribute resources across two Availability Zones for High Availability (HA)
  azs = ["ap-southeast-1a", "ap-southeast-1b"]

  # CORE SECURITY: Isolate all EC2 Worker Nodes, Databases, and Kafka into Private Subnets. 
  # Hackers cannot cURL or access these IPs directly from the Internet.
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  # Public Subnets act as the "storefront", containing only Load Balancers (ELB) to receive incoming traffic.
  public_subnets = ["10.0.101.0/24", "10.0.102.0/24"]

  # Even trapped in Private Subnets, EC2 instances still need internet access to pull Docker Images 
  # or call Stripe API. The NAT Gateway acts as a one-way proxy (Outbound only, no Inbound).
  enable_nat_gateway = true

  # HIGH AVAILABILITY (HA): Deploying 1 NAT Gateway per Data Center (Availability Zone). 
  # If Zone A goes dark, Zone B remains connected to the internet without a Single Point of Failure (SPOF).
  one_nat_gateway_per_az = true

  # Mandatory AWS tags. Kubernetes (EKS) scans for these exact tags to know 
  # which subnet to place the auto-generated Internet-facing Load Balancers into.
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  # Mandatory AWS tags. Kubernetes (EKS) uses these tags to place Internal Load Balancers.
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

# --- 2. Elastic Kubernetes Service (EKS) Cluster ---
module "eks" {
  # Use the official AWS EKS module from Terraform Registry
  source  = "terraform-aws-modules/eks/aws"
  version = "19.16.0"

  # Name of the Kubernetes cluster
  cluster_name = "omnipayx-cluster"
  # The Kubernetes version to install on the control plane and worker nodes
  cluster_version = "1.28"

  # Link the EKS cluster to the VPC created above
  vpc_id = module.vpc.vpc_id

  # Deploy all Worker Nodes into Private Subnets to keep them hidden from hackers.
  subnet_ids = module.vpc.private_subnets

  # Allow developers/admins to run `kubectl` commands from their local machines via public internet
  cluster_endpoint_public_access = true

  # MANAGED COMPUTE: EKS automatically rents EC2 instances, updates the OS, and attaches 
  # them to the Kubernetes cluster. Zero manual server administration is required.
  eks_managed_node_groups = {
    core_nodes = {
      # The absolute minimum number of nodes to keep running
      min_size = 1

      # AUTO-SCALING: If the system gets overloaded (e.g., flash sales, DDoS), AWS automatically 
      # spawns up to 3 servers to handle the load, then scales down to save costs.
      max_size = 3

      # The initial number of nodes to spin up
      desired_size = 2

      # The hardware specs for the EC2 instances. t3.medium has sufficient CPU/RAM for 3 Java microservices.
      instance_types = ["t3.medium"]
    }
  }
}
