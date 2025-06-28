variable "num_control_nodes" {
  type    = number
  default = 1
}

variable "num_worker_nodes" {
  type    = number
  default = 3
}

# |-----------------------------------------------------|
# |                  PROXMOX VARIABLES                  |
# |-----------------------------------------------------|
variable "pm_api_url" {
  description = "Proxmox URL"
  type        = string
}

variable "pm_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
  sensitive   = true
}

variable "pm_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

# |-----------------------------------------------------|
# |              CONTROL NODE VARIABLES                 |
# |-----------------------------------------------------|
variable "control_node_name" {
  description = "Name for the control nodes"
  type        = string
}

variable "control_node_cores" {
  description = "Number of cores for the CPU (Control node)"
  type        = number
  default     = 2
}

variable "control_node_disk_size" {
  description = "Size of the disk in GB (Control node)"
  type        = number
  default     = 32
}

variable "control_node_ram_size" {
  description = "Size of RAM in MB (Control node)"
  type        = number
  default     = 2048
}

variable "control_node_ips" {
  description = "List of static IPs to assign to each control node"
  type        = list(string)
}

variable "control_node_prox_target_node" {
  description = "List of Proxmox node where the control node will be created"
  type        = list(string)
}

# |-----------------------------------------------------|
# |               WORKER NODE VARIABLES                 |
# |-----------------------------------------------------|
variable "worker_node_name" {
  description = "Name of the VM"
  type        = string
}

variable "worker_node_cores" {
  description = "Number of cores for the CPU (Worker node)"
  type        = number
  default     = 1
}

variable "worker_node_disk_size" {
  description = "Size of the disk in GB (worker node)"
  type        = number
  default     = 32
}

variable "worker_node_ram_size" {
  description = "Size of RAM in MB (worker node)"
  type        = number
  default     = 1024
}

variable "worker_node_prox_target_node" {
  description = "List of Proxmox node where the worker node will be created"
  type        = list(string)
}


variable "worker_node_ips" {
  description = "List of static IPs to assign to each worker node"
  type        = list(string)
}

# |-----------------------------------------------------|
# |                  GENERAL VARIABLES                  |
# |-----------------------------------------------------|
variable "template_name" {
  description = "Base template to clone from"
  type        = string
}

variable "gateway_ip" {
  description = "IP gateway"
  type        = string
}

variable "dns_ip" {
  description = "DNS IP"
  type        = string
}

variable "storage_name" {
  description = "Proxmox storage name to save the VM Disk"
  type        = string
}

variable "vm_user" {
  description = "Default username"
  type        = string
}

variable "github_user" {
  description = "Github user to pull keys from"
  type        = string
}

# variable "ssh_key" {
#   description = "SSH public key to inject into the VM"
#   type        = string
# }
