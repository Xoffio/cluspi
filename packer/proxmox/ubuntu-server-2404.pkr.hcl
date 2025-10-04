# Packer Template to create an Ubuntu Server 20.04 on Proxmox

#  ____________________________________________________________
# |                   Variable definitions                     |
# |____________________________________________________________|
variable "proxmox_api_url" {
  type    = string
  default = env("PM_API_URL")
}

variable "proxmox_api_token_id" {
  type    = string
  default = env("PM_API_TOKEN_ID")
}

variable "proxmox_api_token_secret" {
  type      = string
  default   = env("PM_API_TOKEN_SECRET")
  sensitive = true
}

variable "node_name" {
  type        = string
  description = "Proxmox node name"
}

variable "template_id" {
  type        = number
  description = "VM ID for the template"
}

variable "autoinstall_ip" {
  type    = string
  default = "{{ .HTTPIP }}" # leave blank to fall back to .HTTPIP
}

variable "ssh_username" {
  type        = string
  description = "SSH username to connect to the template"
}

# Resource Definition for the VM Template
source "proxmox-iso" "ubuntu-server-2404" {

  # Proxmox Connection Settings
  proxmox_url = "${var.proxmox_api_url}"
  username    = "${var.proxmox_api_token_id}"
  token       = "${var.proxmox_api_token_secret}"

  # (Optional) Skip TLS Verification
  insecure_skip_tls_verify = true

  # ---- VM General Settings ----
  node                 = var.node_name
  vm_id                = var.template_id
  vm_name              = "ubuntu-server-2404"
  template_description = "Ubuntu Server 20.04 Image"

  # ---- VM OS Settings ---- 
  os = "l26" # Linux2.6+
  boot_iso {
    type = "scsi"

    # (Option 1) Local ISO File
    # iso_file = "prox-backups:iso/noble-server-cloudimg-amd64.img"
    # - or -
    # (Option 2) Download ISO
    iso_url          = "https://releases.ubuntu.com/noble/ubuntu-24.04.3-live-server-amd64.iso"
    iso_checksum     = "c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"
    iso_storage_pool = "local"
    unmount          = true
    iso_download_pve = true
  }

  # ---- VM System Settings ----
  machine    = "q35"
  qemu_agent = true

  # ---- VM Hard Disk Settings ----
  scsi_controller = "virtio-scsi-pci"

  disks {
    type         = "virtio"
    storage_pool = "local"
    disk_size    = "16G"
    format       = "qcow2"
  }

  # ---- VM CPU Settings ---- 
  cores    = "1"
  cpu_type = "host"

  # ---- VM Memory Settings ----
  memory = "2048"

  # ---- VM Network Settings ----
  network_adapters {
    bridge = "vmbr0"
    model  = "virtio"
  }

  # VM Cloud-Init Settings
  cloud_init              = true
  cloud_init_storage_pool = "local"

  # PACKER Boot Commands 
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    "<bs><bs><bs><bs><wait>",
    # "autoinstall \"ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/\" ---<wait>",
    "autoinstall \"ds=nocloud-net;s=http://${var.autoinstall_ip}:{{ .HTTPPort }}/\" ---<wait>",
    "<f10><wait>"
  ]

  boot      = "c"
  boot_wait = "5s"

  # PACKER Autoinstall Settings
  http_directory = "${path.root}/http-files"
  # (Optional) Bind IP Address and Port
  # http_bind_address = "192.168.8.8"
  # http_port_min     = 8880
  # http_port_max     = 8890

  ssh_username = "${var.ssh_username}"

  # (Option 1) Add your Password here
  # ssh_password = "STRONG_PASS_HERE"
  # - or -
  # (Option 2) Add your Private SSH KEY file here
  ssh_private_key_file = "~/.ssh/id_rsa"

  # Raise the timeout, when installation takes longer
  ssh_timeout = "20m"
}

build {
  name    = "ubuntu-server-2404"
  sources = ["source.proxmox-iso.ubuntu-server-2404"]

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox #1
  # Shell (cleanup + make it clone-safe)
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo rm /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo apt -y autoremove --purge",
      "sudo apt -y clean",
      "sudo apt -y autoclean",
      "sudo cloud-init clean",
      "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
      "sudo rm -f /etc/netplan/00-installer-config.yaml",
      "sudo sync",
    ]
  }

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox #2
  provisioner "file" {
    source      = "${path.root}/cloud-init-config/99-pve.cfg"
    destination = "/tmp/99-pve.cfg"
  }

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox #3
  provisioner "shell" {
    inline = [
      "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg"
    ]
  }
}
