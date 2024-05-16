#!/bin/bash

# This function assumes that the first argument is an IP address and the second argument is the talos directory
# It checks the health of the cluster
check_health() {
  local primary_controller=$1
  local n=0
  local retries=5
  local talos_dir=$2

  echo "[INFO] Performing health check on the cluster"

  until [ "$n" -ge "$retries" ]; do
    if talosctl --talosconfig="${talos_dir}"/talosconfig --nodes "${primary_controller}" -e "${primary_controller}" health; then
      break
    else
      n=$((n+1))
      sleep 5
    fi
  done

  echo "[INFO] Successfully performed health check on the cluster"
}

# This function assumes that the first argument is an IP address, the second argument is the talos directory
# The third argument is list of master node ips in format "master-0,master-1,master-2" and
# The fourth argument is the list of worker node ips in format "worker-0,worker-1,worker-2"
# It updates the kubeconfig
update_kubeconfig() {
  local primary_controller=$1
  local talos_dir=$2
  local master_nodes=$3
  local worker_nodes_ips=$4

  # convert the worker nodes ips to a space separated string
  worker_nodes_ips=$(echo "${worker_nodes_ips}" | tr ',' ' ')
  # convert the master nodes ips to a space separated string
  master_nodes=$(echo "${master_nodes}" | tr ',' ' ')

  echo "[INFO] Setting the TALOSCONFIG environment variable"
  export TALOSCONFIG="${talos_dir}"/talosconfig

  echo "[INFO] Retrieving the kubeconfig for the cluster"
  talosctl kubeconfig --nodes "${primary_controller}" -e "${primary_controller}" --talosconfig="${talos_dir}"/talosconfig --force

  echo "[INFO] Setting the endpoint and node values for the talosctl command"
  talosctl config endpoint "${master_nodes}"
  talosctl config node "${master_nodes} ${worker_nodes_ips}"

  echo "[INFO] Successfully retrieved the kubeconfig from the cluster"
}

# This function assumes that the first argument is a list of all the worker nodes names in format "worker-0,worker-1,worker-2"
# It uses kubectl to properly label the worker nodes
label_worker_nodes() {
  local worker_nodes=$1

  echo "[INFO] Labeling the worker nodes"

  IFS=',' read -r -a nodes <<< "$worker_nodes"

  for node in "${nodes[@]}"; do
    kubectl label node "${node}" node-role.kubernetes.io/worker=worker
  done

  echo "[INFO] Successfully labeled the worker nodes"
}

# This function assumes that the first argument is a github username, the second argument is a github repository name,
# the third argument is the github token and the fourth argument is the cluster name
# It initializes the fluxcd
initialize_fluxcd() {
  local github_username=$1
  local github_repository=$2
  local github_token=$3
  local cluster_name=$4

  echo "[INFO] Initializing the fluxcd"

  export GITHUB_TOKEN="${github_token}"

  flux bootstrap github \
    --owner="${github_username}" \
    --repository="${github_repository}" \
    --branch=main \
    --path=clusters/"${cluster_name}" \
    --personal \
    --token-auth \

  echo "[INFO] Successfully initialized the fluxcd"
}

# This function assumes that the first argument is an IP address, the second argument is the talos directory
# the third argument is a list of all the worker nodes names
# the fourth argument is the list of worker node ips in format
# the fifth argument is the list of master node ips in format
# the sixth argument is the github username
# the seventh argument is the github token
# the eighth argument is the github repository
# the ninth argument is the cluster name
main() {
  local primary_controller=$1
  local talos_dir=$2
  local worker_nodes_names=$3
  local worker_nodes_ips=$4
  local master_nodes_ips=$5
  local github_username=$6
  local github_token=$7
  local github_repository=$8
  local cluster_name=$9

  # Sleep for 30 seconds to allow the cluster to come up
  echo "[INFO] Sleeping for 30 seconds to allow the cluster to come up"
  sleep 30

  check_health "${primary_controller}" "${talos_dir}"
  update_kubeconfig "${primary_controller}" "${talos_dir}" "${master_nodes_ips}" "${worker_nodes_ips}"
  label_worker_nodes "${worker_nodes_names}"
  initialize_fluxcd "${github_username}" "${github_repository}" "${github_token}" "${cluster_name}"
}

build_args() {
  local worker_nodes_names=""
  local master_nodes_ips=""
  local worker_nodes_ips=""
  local primary_controller=""
  local talos_dir=""
  local cluster_name=""
  local username=""
  local token=""
  local repository=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
       -p|--primary-controller)
         shift
         primary_controller=$1
         shift
         ;;
       -t|--talos-dir)
         shift
         talos_dir=$1
         shift
         ;;
      -w|--worker-nodes-names)
         shift
         worker_nodes_names=$1
         shift
         ;;
      -m|--master-nodes-ips)
        shift
        master_nodes_ips=$1
        shift
        ;;
      -i|--worker-nodes-ips)
        shift
        worker_nodes_ips=$1
        shift
        ;;
      -c|--cluster-name)
        shift
        cluster_name=$1
        shift
        ;;
      -u|--username)
        shift
        username=$1
        shift
        ;;
      -k|--token)
        shift
        token=$1
        shift
        ;;
      -r|--repository)
        shift
        repository=$1
        shift
        ;;
      *)
        echo "Unknown parameter passed: $1"
        exit 1
        ;;
    esac
  done

  main "${primary_controller}" "${talos_dir}" "${worker_nodes_names}" "${worker_nodes_ips}" "${master_nodes_ips}" "${username}" "${token}" "${repository}" "${cluster_name}"
}

build_args "$@"
