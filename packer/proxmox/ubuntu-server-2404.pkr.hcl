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


# Resource Definition for the VM Template
source "proxmox-iso" "ubuntu-server-2404" {

  # Proxmox Connection Settings
  proxmox_url = "${var.proxmox_api_url}"
  username    = "${var.proxmox_api_token_id}"
  token       = "${var.proxmox_api_token_secret}"

  # (Optional) Skip TLS Verification
  insecure_skip_tls_verify = true

  # ---- VM General Settings ----
  node                 = "${var.node_name}"
  vm_id                = "${var.template_id}"
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

  # VM Network Settings
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = "false"
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


  # (Option 1) Add your Password here
  # ssh_password = "61guney61"
  # - or -
  # (Option 2) Add your Private SSH KEY file here

  # Raise the timeout, when installation takes longer
  ssh_timeout = "20m"
}

