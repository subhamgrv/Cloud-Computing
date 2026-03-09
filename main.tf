variable "group_number" {
  type    = string
  default = "47"
}

variable "app_instance_count" {
  type    = number
  default = 2
}

variable "github_token" {
  type        = string
  description = "GitHub Personal Access Token for cloning repos"
  sensitive   = true
}

locals {
  auth_url        = "https://10.32.4.29:5000/v3"
  user_name       = "CloudComp47"
  user_password   = "demo"
  tenant_name     = "CloudComp${var.group_number}"
  router_name     = "CloudComp${var.group_number}-router"
  image_name      = "ubuntu-22.04-jammy-server-cloud-image-amd64"
  flavor_name     = "m1.small"
  region_name     = "RegionOne"
  floating_net    = "ext_net"
  dns_nameservers = ["10.33.16.100"]
}

terraform {
  required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = ">= 2.0.0"
    }
  }
}

provider "openstack" {
  user_name   = local.user_name
  tenant_name = local.tenant_name
  password    = local.user_password
  auth_url    = local.auth_url
  region      = local.region_name
  insecure    = true
}

resource "openstack_compute_keypair_v2" "frontend_keypair" {
  name       = "frontend-pubkey"
  public_key = file("${path.module}/id_rsa.pub")
}

resource "openstack_networking_secgroup_v2" "frontend_secgroup" {
  name        = "frontend-secgroup"
  description = "Security group for frontend, backend, and database access"
}

resource "openstack_networking_secgroup_rule_v2" "allow_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  security_group_id = openstack_networking_secgroup_v2.frontend_secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "allow_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = openstack_networking_secgroup_v2.frontend_secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "allow_mariadb_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3306
  port_range_max    = 3306
  remote_ip_prefix  = "192.168.255.0/24"
  security_group_id = openstack_networking_secgroup_v2.frontend_secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "allow_react_dev" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3000
  port_range_max    = 3000
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.frontend_secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "allow_backend_api" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8000
  port_range_max    = 8000
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.frontend_secgroup.id
}

resource "openstack_networking_network_v2" "frontend_network" {
  name           = "frontend-network"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "frontend_subnet" {
  name            = "frontend-subnet"
  network_id      = openstack_networking_network_v2.frontend_network.id
  cidr            = "192.168.255.0/24"
  ip_version      = 4
  dns_nameservers = local.dns_nameservers
}

data "openstack_networking_router_v2" "frontend_router" {
  name = local.router_name
}

resource "openstack_networking_router_interface_v2" "frontend_router_interface" {
  router_id = data.openstack_networking_router_v2.frontend_router.id
  subnet_id = openstack_networking_subnet_v2.frontend_subnet.id
}

resource "openstack_networking_port_v2" "frontend_app_port" {
  count              = var.app_instance_count
  name               = "frontend-app-port-${count.index}"
  network_id         = openstack_networking_network_v2.frontend_network.id
  security_group_ids = [openstack_networking_secgroup_v2.frontend_secgroup.id]

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.frontend_subnet.id
  }
}

resource "openstack_networking_port_v2" "db_port" {
  name               = "db-port"
  network_id         = openstack_networking_network_v2.frontend_network.id
  security_group_ids = [openstack_networking_secgroup_v2.frontend_secgroup.id]

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.frontend_subnet.id
  }
}

resource "openstack_compute_instance_v2" "frontend_app_instance" {
  count           = var.app_instance_count
  name            = "frontend-app-instance-${count.index}"
  image_name      = local.image_name
  flavor_name     = local.flavor_name
  key_pair        = openstack_compute_keypair_v2.frontend_keypair.name
  security_groups = [openstack_networking_secgroup_v2.frontend_secgroup.name]

  network {
    port = openstack_networking_port_v2.frontend_app_port[count.index].id
  }

  user_data = templatefile("${path.module}/userdata-app.sh.tpl", {
    db_host        = one(openstack_networking_port_v2.db_port.all_fixed_ips)
    public_api_url = "http://${openstack_networking_floatingip_v2.backend_fip.address}:8000"
    github_token   = var.github_token
  })
}

resource "openstack_compute_instance_v2" "database_instance" {
  name            = "database-instance"
  image_name      = local.image_name
  flavor_name     = local.flavor_name
  key_pair        = openstack_compute_keypair_v2.frontend_keypair.name
  security_groups = [openstack_networking_secgroup_v2.frontend_secgroup.name]

  network {
    port = openstack_networking_port_v2.db_port.id
  }

  user_data = file("${path.module}/userdata-db.sh")
}

resource "openstack_lb_loadbalancer_v2" "backend_lb" {
  name          = "backend-api-lb"
  vip_subnet_id = openstack_networking_subnet_v2.frontend_subnet.id
}

resource "openstack_lb_listener_v2" "backend_listener" {
  protocol        = "HTTP"
  protocol_port   = 8000
  loadbalancer_id = openstack_lb_loadbalancer_v2.backend_lb.id
}

resource "openstack_lb_pool_v2" "backend_pool" {
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.backend_listener.id
}

resource "openstack_lb_member_v2" "backend_members" {
  count         = var.app_instance_count
  pool_id       = openstack_lb_pool_v2.backend_pool.id
  address       = openstack_networking_port_v2.frontend_app_port[count.index].all_fixed_ips[0]
  protocol_port = 8000
  subnet_id     = openstack_networking_subnet_v2.frontend_subnet.id
}

resource "openstack_lb_monitor_v2" "backend_monitor" {
  pool_id        = openstack_lb_pool_v2.backend_pool.id
  type           = "HTTP"
  delay          = 5
  timeout        = 5
  max_retries    = 3
  http_method    = "GET"
  url_path       = "/api/health"
  expected_codes = "200"
}

resource "openstack_networking_floatingip_v2" "backend_fip" {
  pool = local.floating_net
}

resource "openstack_networking_floatingip_associate_v2" "backend_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.backend_fip.address
  port_id     = openstack_lb_loadbalancer_v2.backend_lb.vip_port_id
}

output "backend_api_url" {
  value = "http://${openstack_networking_floatingip_v2.backend_fip.address}:8000"
}

resource "openstack_networking_floatingip_v2" "frontend_fip" {
  pool = local.floating_net
}

resource "openstack_networking_floatingip_associate_v2" "frontend_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.frontend_fip.address
  port_id     = openstack_networking_port_v2.frontend_app_port[0].id
}

output "frontend_floating_ip" {
  value = openstack_networking_floatingip_v2.frontend_fip.address
}

output "db_private_ip" {
  value = openstack_networking_port_v2.db_port.all_fixed_ips[0]
}

output "frontend_app_private_ips" {
  value = [
    for port in openstack_networking_port_v2.frontend_app_port :
    port.all_fixed_ips[0]
  ]
}

output "component_urls" {
  value = {
    "Frontend (React)"  = "http://${openstack_networking_floatingip_v2.frontend_fip.address}:3000"
    "Backend API"       = "http://${openstack_networking_floatingip_v2.backend_fip.address}:8000/api/"
    "Health Endpoint"   = "GET http://${openstack_networking_floatingip_v2.backend_fip.address}:8000/api/health"
  }
}