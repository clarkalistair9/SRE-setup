terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.30"
    }
  }
  backend "http" {}
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

variable "project" {
  type = string
}

variable "region"  {
  type    = string
  default = "us-central1"
}

variable "zone"    {
  type    = string
  default = "us-central1-a"
}

variable "environment" {
  type    = string
  default = "sre-monitoring"
}

variable "ssh_public_key" {
  type = string
}

resource "google_compute_network" "vpc" {
  name                    = "${var.environment}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "public"
  ip_cidr_range = "10.2.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_compute_firewall" "allow_ingress" {
  name    = "${var.environment}-allow-ingress"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "3000", "9090"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_address" "ip" {
  name   = "${var.environment}-ip"
  region = var.region
}

data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2204-lts"
  project = "ubuntu-os-cloud"
}

resource "google_compute_instance" "vm" {
  name         = "${var.environment}-vm"
  machine_type = "e2-standard-2"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 30
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork         = google_compute_subnetwork.subnet.id
    access_config {
      nat_ip = google_compute_address.ip.address
    }
  }

  metadata = {
    ssh-keys   = "ubuntu:${var.ssh_public_key}"
    user-data  = templatefile("${path.module}/user_data.sh", { hostname = "${var.environment}-server" })
  }
}

output "public_ip"   { value = google_compute_address.ip.address }
output "instance_id" { value = google_compute_instance.vm.id }
output "ssh_user"    { value = "ubuntu" }




