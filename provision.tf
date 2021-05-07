terraform {
	required_version = ">= 0.13"
	required_providers {
		libvirt = {
			source  = "dmacvicar/libvirt"
			version = "0.6.3"
		}
	}
}

provider "libvirt" {
	uri = "qemu:///system"
}

variable "cidr" {
	type = string
	default = "192.168.100.0/24"
}

resource "libvirt_volume" "ubuntu_base" {
	name = "os_image"
	source = "https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
}

resource "libvirt_volume" "ubuntu_system" {
	name = "ubuntu-test_system"
	base_volume_id = libvirt_volume.ubuntu_base.id
	size = 10 * 1024 * 1024 * 1024
	pool = "fast"
}

resource "libvirt_cloudinit_disk" "ubuntu" {
	name = "ubuntu-test_cloudinit.iso"
	user_data = templatefile("${path.module}/templates/user_data.cfg",
		{
			hostname = "ubuntu-test"
		}
	)
	pool = "slow"
}

resource "libvirt_network" "ubuntu" {
	name = "ubuntu-test"
	mode = "nat"
	domain = "test.local"
	addresses = [var.cidr]
	
	dhcp {
		enabled = true
	}

	dns {
		enabled = true
		local_only = false
	}
}

resource "libvirt_domain" "ubuntu" {
	name = "ubuntu-test"
	
	vcpu = 2
	memory = 1024
	
	disk {
		volume_id = libvirt_volume.ubuntu_system.id
	}

	cloudinit = libvirt_cloudinit_disk.ubuntu.id

	network_interface {
		network_id = libvirt_network.ubuntu.id
		addresses = [cidrhost(var.cidr, 51)]
		wait_for_lease = true
	}
}

output "ubuntu-test_ip" {
	value = libvirt_domain.ubuntu.network_interface.0.addresses
}
