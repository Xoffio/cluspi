is_control_node_types_valid() {
  if [ "${#CONTROL_NODE_TYPES[@]}" != "$CONTROL_NODE_COUNT" ]; then
    echo "There is a format issue. The amount of CONTROL_NODE_TYPES doesn't match CONTROL_NODE_COUNT"
    exit 1
  fi

  # control_ext_count=0
  # for type in "${CONTROL_NODE_TYPES[@]}"; do
  #   if [ "$type" = "EXT" ]; then
  #     ((control_ext_count++))
  #   fi
  # done
  #
  # # Validate against CONTROL_NODE_EXTS
  # if [ "$control_ext_count" -ne "${#CONTROL_NODE_EXTS[@]}" ]; then
  #   echo "Mismatch: $control_ext_count EXT nodes, but ${#CONTROL_NODE_EXTS[@]} CONTROL_NODE_EXTS defined."
  #   exit 1
  # fi

  if [ "${#CONTROL_NODE_NAMES[@]}" -ne "$CONTROL_NODE_COUNT" ]; then
    # echo "${#CONTROL_NODE_NAMES[@]} $CONTROL_NODE_COUNT"
    echo "You need to set CONTROL_NODE_NAMES to $CONTROL_NODE_COUNT names"
    exit 1
  fi
}

is_worker_node_types_valid() {
  if [ "${#WORKER_NODE_TYPES[@]}" != "$WORKER_NODE_COUNT" ]; then
    echo "There is a format issue. The amount of WORKER_NODE_TYPES doesn't match WORKER_NODE_COUNT"
    exit 1
  fi

  # worker_ext_count=0
  # for type in "${WORKER_NODE_TYPES[@]}"; do
  #   if [ "$type" = "EXT" ]; then
  #     ((worker_ext_count++))
  #   fi
  # done
  #
  # # Validate against WORKER_NODE_EXTS
  # if [ "$worker_ext_count" -ne "${#WORKER_NODE_EXTS[@]}" ]; then
  #   echo "Mismatch: $worker_ext_count EXT nodes, but ${#WORKER_NODE_EXTS[@]} WORKER_NODES_EXTS defined."
  #   exit 1
  # fi

  if [ "${#WORKER_NODE_NAMES[@]}" -ne "$WORKER_NODE_COUNT" ]; then
    echo "${#WORKER_NODE_NAMES[@]} $WORKER_NODE_COUNT"
    echo "You need to set WORKER_NODE_NAMES to $WORKER_NODE_COUNT names"
    exit 1
  fi
}
