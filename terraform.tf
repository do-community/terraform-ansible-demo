variable "do_token" {
}

variable "ssh_fingerprint" {
}

provider "digitalocean" {
  token = var.do_token
}

# create two demo droplets
resource "digitalocean_droplet" "demo-01" {
  image    = "ubuntu-20-04-x64"
  name     = "demo-01"
  region   = "nyc3"
  size     = "s-1vcpu-1gb"
  ssh_keys = [var.ssh_fingerprint]
}

resource "digitalocean_droplet" "demo-02" {
  image    = "ubuntu-20-04-x64"
  name     = "demo-02"
  region   = "nyc3"
  size     = "s-1vcpu-1gb"
  ssh_keys = [var.ssh_fingerprint]
}

# create a loadbalancer that points to the two droplets
resource "digitalocean_loadbalancer" "demo-lb" {
  name   = "demo-lb"
  region = "nyc3"

  droplet_ids = [
    digitalocean_droplet.demo-01.id,
    digitalocean_droplet.demo-02.id,
  ]

  forwarding_rule {
    entry_port     = 80
    entry_protocol = "http"

    target_port     = 80
    target_protocol = "http"
  }
}

# create a firewall that only accepts port 80 traffic from the load balancer
resource "digitalocean_firewall" "demo-firewall" {
  name = "demo-firewall"

  droplet_ids = [
    digitalocean_droplet.demo-01.id,
    digitalocean_droplet.demo-02.id,
  ]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0"]
  }
  inbound_rule {
    protocol                  = "tcp"
    port_range                = "80"
    source_load_balancer_uids = [digitalocean_loadbalancer.demo-lb.id]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "all"
    destination_addresses = ["0.0.0.0/0"]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "all"
    destination_addresses = ["0.0.0.0/0"]
  }
}

# create an ansible inventory file
resource "null_resource" "ansible-provision" {
  depends_on = [
    digitalocean_droplet.demo-01,
    digitalocean_droplet.demo-02,
  ]

  provisioner "local-exec" {
    command = "echo '${digitalocean_droplet.demo-01.name} ansible_host=${digitalocean_droplet.demo-01.ipv4_address} ansible_ssh_user=root ansible_python_interpreter=/usr/bin/python3' > inventory"
  }

  provisioner "local-exec" {
    command = "echo '${digitalocean_droplet.demo-02.name} ansible_host=${digitalocean_droplet.demo-02.ipv4_address} ansible_ssh_user=root ansible_python_interpreter=/usr/bin/python3' >> inventory"
  }
}

# output the load balancer ip
output "ip" {
  value = digitalocean_loadbalancer.demo-lb.ip
}

