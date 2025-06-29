# Define the Proxmox VM resource
resource "proxmox_vm_qemu" "k3s_control_nodes" {
  count       = var.num_control_nodes
  name        = "${var.control_node_name}${format("%02d", count.index + 1)}" # Name of the new VM
  target_node = var.control_node_prox_target_node[count.index]               # Proxmox node where the VM will be created
  clone       = var.template_name                                            # Base template to clone from
  full_clone  = true                                                         # Create a full independent clone
  scsihw      = "virtio-scsi-single"
  os_type     = "cloud-init" # Enable Cloud-Init support

  memory = var.control_node_ram_size

  cpu {
    cores = var.control_node_cores
    type  = "host"
  }

  # Define disk layout using both SCSI and IDE (for Cloud-Init drive)
  disks {
    ide {
      ide2 {
        cloudinit {
          storage = var.storage_name # Attach Cloud-Init disk on ide2 using 'local' storage
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          storage = var.storage_name           # Main boot disk also on 'local' storage
          size    = var.control_node_disk_size # Disk size in GB
        }
      }
    }
  }

  # Define virtual NIC configuration
  network {
    id        = 0
    model     = "virtio" # Use VirtIO network interface for performance
    bridge    = "vmbr0"  # Bridge interface to attach VM NIC to
    firewall  = false
    link_down = false # Ensure the NIC is up
  }

  # Attach a serial console for headless/Cloud-Init compatibility
  serial {
    id   = 0
    type = "socket"
  }

  # Cloud-Init user configuration
  ciuser     = var.vm_user                                                    # Default username for login
  ipconfig0  = "ip=${var.control_node_ips[count.index]},gw=${var.gateway_ip}" # Static IPv4 network configuration
  nameserver = var.dns_ip                                                     # DNS resolver

  # Inject public SSH key for the ciuser
  # sshkeys = var.ssh_key
  sshkeys = data.http.github_keys.response_body
}
