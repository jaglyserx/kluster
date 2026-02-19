# PROVIDER
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.60.0"
    }
  }
}

# Configure the Hetzner Cloud Provider with your token
provider "hcloud" {
  token = var.hcloud_token
}


# NETWORKING
resource "hcloud_network" "kluster_private_network" {
  name     = "kluster"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "kluster_private_network_subnet" {
  type         = "cloud"
  network_id   = hcloud_network.kluster_private_network.id
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

output "kluster_network_id" {
  value = hcloud_network.kluster_private_network.id
}


# MASTER NODE
resource "hcloud_server" "master-node" {
  name        = "master-node"
  image       = "ubuntu-24.04"
  server_type = "cax11"
  location    = var.location
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
  network {
    network_id = hcloud_network.kluster_private_network.id
    # IP Used by the master node, needs to be static
    # Here the worker nodes will use 10.0.1.1 to communicate with the master node
    ip = "10.0.1.1"
  }
  user_data = file("${path.module}/cloud-init.yaml")

  lifecycle {
    ignore_changes = [user_data]
  }

  # If we don't specify this, Terraform will create the resources in parallel
  # We want this node to be created after the private network is created
  depends_on = [hcloud_network_subnet.kluster_private_network_subnet]
}


# WORKER NODE
resource "hcloud_server" "worker-nodes" {
  count = 1

  # The name will be worker-node-0, worker-node-1, worker-node-2...
  name        = "worker-node-${count.index}"
  image       = "ubuntu-24.04"
  server_type = "cax11"
  location    = var.location
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
  network {
    network_id = hcloud_network.kluster_private_network.id
  }
  user_data = file("${path.module}/cloud-init-worker.yaml")

  lifecycle {
    ignore_changes = [user_data]
  }

  depends_on = [hcloud_network_subnet.kluster_private_network_subnet, hcloud_server.master-node]
}


# DNS MANAGEMENT
resource "hcloud_zone" "joels_computer" {
  name = "joels.computer"
  mode = "primary"

  ttl = 10800
}

