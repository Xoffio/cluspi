format_ips_for_tfvars() {
  local var_name="$1"
  local ip_list="$2"
  local padding="$3"

  IFS=',' read -ra IPS <<<"$ip_list"
  local formatted_ips
  formatted_ips=$(printf '"%s", ' "${IPS[@]}")
  formatted_ips="[${formatted_ips%, }]"

  printf "%s%*s%s\n" "$var_name" "$padding" "" "= $formatted_ips"
}

format_control_node_names() {
  local var_name="$1"
  local padding="$2"

  formatted_names=()
  for i in "${!CONTROL_NODE_TYPES[@]}"; do
    if [[ "${CONTROL_NODE_TYPES[$i]}" == "PROX" ]]; then
      formatted_names+=("${CONTROL_NODE_NAMES[$i]}")
    fi
  done

  # Export to Terraform format
  PROX_NODE_NAMES_STR=$(printf '"%s",' "${formatted_names[@]}")
  PROX_NODE_NAMES_STR="[${PROX_NODE_NAMES_STR%,}]"

  printf "%s%*s%s\n" "$var_name" "$padding" "" "= $PROX_NODE_NAMES_STR"
}

format_worker_node_names() {
  local var_name="$1"
  local padding="$2"

  formatted_names=()
  for i in "${!WORKER_NODE_TYPES[@]}"; do
    if [[ "${WORKER_NODE_TYPES[$i]}" == "PROX" ]]; then
      formatted_names+=("${WORKER_NODE_NAMES[$i]}")
    fi
  done

  # Export to Terraform format
  PROX_NODE_NAMES_STR=$(printf '"%s",' "${formatted_names[@]}")
  PROX_NODE_NAMES_STR="[${PROX_NODE_NAMES_STR%,}]"

  printf "%s%*s%s\n" "$var_name" "$padding" "" "= $PROX_NODE_NAMES_STR"
}

create_terraform_vars_file() {
  : "${CONTROL_NODE_COUNT:?CONTROL_NODE_COUNT is required}"
  : "${WORKER_NODE_COUNT:?WORKER_NODE_COUNT is required}"
  : "${PM_API_URL:?PM_API_URL is required}"
  : "${PM_API_TOKEN_ID:?PM_API_TOKEN_ID is required}"
  : "${PM_API_TOKEN_SECRET:?PM_API_TOKEN_SECRET is required}"

  : "${CONTROL_NODE_IPS:?CONTROL_NODE_IPS is required}"
  : "${CONTROL_NODE_PROX_TARGET_NODE:?CONTROL_NODE_PROX_TARGET_NODE is required}"

  : "${WORKER_NODE_IPS:?WORKER_NODE_IPS is required}"
  : "${WORKER_NODE_PROX_TARGET_NODE:?WORKER_NODE_PROX_TARGET_NODE is required}"

  : "${CONTROL_NODE_LB_IPS:?CONTROL_NODE_LB_IPS is required}"
  : "${CONTROL_NODE_LB_PROX_TARGET_NODE:?CONTROL_NODE_LB_PROX_TARGET_NODE is required}"

  : "${TEMPLATE_NAME:?TEMPLATE_NAME is required}"
  : "${STORAGE_NAME:?STORAGE_NAME is required}"
  : "${GATEWAY_IP:?GATEWAY_IP is required}"
  : "${DNS_IP:?DNS_IP is required}"
  : "${VM_USER:?VM_USER is required}"
  : "${GITHUB_USER:?GITHUB_USER is required}" # TODO: What if the user doesn't have their keys in Github. Fix this

  echo "control_node_count  = ${CONTROL_NODE_COUNT_TF}" >"$terraform_var_file"
  echo "worker_node_count   = ${WORKER_NODE_COUNT_TF}" >>"$terraform_var_file"
  echo "pm_api_url          = \"${PM_API_URL}\"" >>"$terraform_var_file"
  echo "pm_api_token_id     = \"${PM_API_TOKEN_ID}\"" >>"$terraform_var_file"
  echo "pm_api_token_secret = \"${PM_API_TOKEN_SECRET}\"" >>"$terraform_var_file"
  echo "" >>"$terraform_var_file"

  # [[ -n "${CONTROL_NODE_NAME:-}" ]] && echo "control_node_name             = \"${CONTROL_NODE_NAME}\"" >>"$terraform_var_file"
  format_control_node_names "control_node_names" "12" >>"$terraform_var_file"
  [[ -n "${CONTROL_NODE_CORES:-}" ]] && echo "control_node_cores            = ${CONTROL_NODE_CORES}" >>"$terraform_var_file"
  [[ -n "${CONTROL_NODE_DISK_SIZE:-}" ]] && echo "control_node_disk_size        = ${CONTROL_NODE_DISK_SIZE}" >>"$terraform_var_file"
  [[ -n "${CONTROL_NODE_RAM_SIZE:-}" ]] && echo "control_node_ram_size         = ${CONTROL_NODE_RAM_SIZE}" >>"$terraform_var_file"

  format_ips_for_tfvars "control_node_ips" "$CONTROL_NODE_IPS" "14" >>"$terraform_var_file"
  format_ips_for_tfvars "control_node_prox_target_node" "$CONTROL_NODE_PROX_TARGET_NODE" "1" >>"$terraform_var_file"
  IFS=',' read -ra CONTROL_NODE_IPS <<<"$CONTROL_NODE_IPS"
  echo "" >>"$terraform_var_file"

  # [[ -n "${WORKER_NODE_NAME:-}" ]] && echo "worker_node_name             = \"${WORKER_NODE_NAME}\"" >>"$terraform_var_file"
  format_worker_node_names "worker_node_names" "12" >>"$terraform_var_file"
  [[ -n "${WORKER_NODE_CORES:-}" ]] && echo "worker_node_cores            = ${WORKER_NODE_CORES}" >>"$terraform_var_file"
  [[ -n "${WORKER_NODE_DISK_SIZE:-}" ]] && echo "worker_node_disk_size        = ${WORKER_NODE_DISK_SIZE}" >>"$terraform_var_file"
  [[ -n "${WORKER_NODE_RAM_SIZE:-}" ]] && echo "worker_node_ram_size         = ${WORKER_NODE_RAM_SIZE}" >>"$terraform_var_file"
  format_ips_for_tfvars "worker_node_ips" "$WORKER_NODE_IPS" "14" >>"$terraform_var_file"
  format_ips_for_tfvars "worker_node_prox_target_node" "$WORKER_NODE_PROX_TARGET_NODE" "1" >>"$terraform_var_file"
  IFS=',' read -ra WORKER_NODE_IPS <<<"$WORKER_NODE_IPS"

  echo "" >>"$terraform_var_file"
  [[ -n "${CONTROL_NODE_LB_NAME:-}" ]] && echo "control_node_lb_name             = \"${CONTROL_NODE_LB_NAME}\"" >>"$terraform_var_file"
  format_ips_for_tfvars "control_node_lb_ips" "$CONTROL_NODE_LB_IPS" "14" >>"$terraform_var_file"
  format_ips_for_tfvars "control_node_lb_prox_target_node" "$CONTROL_NODE_LB_PROX_TARGET_NODE" "1" >>"$terraform_var_file"
  IFS=',' read -ra CONTROL_NODE_LB_IPS <<<"$CONTROL_NODE_LB_IPS"

  echo "" >>"$terraform_var_file"
  echo "template_name = \"$TEMPLATE_NAME\"" >>"$terraform_var_file"
  echo "storage_name  = \"$STORAGE_NAME\"" >>"$terraform_var_file"
  echo "gateway_ip    = \"$GATEWAY_IP\"" >>"$terraform_var_file"
  echo "dns_ip        = \"$DNS_IP\"" >>"$terraform_var_file"
  echo "vm_user       = \"$VM_USER\"" >>"$terraform_var_file"
  echo "github_user   = \"$GITHUB_USER\"" >>"$terraform_var_file"
}
