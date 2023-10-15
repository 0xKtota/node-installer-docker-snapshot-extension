#!/bin/bash

# Check if the required commands are present
for cmd in wget whiptail docker docker-compose; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed."
        exit 1
    fi
done

# --- Functions ---

cleanup() {
    # Confirmation before deletion
    read -p "Are you sure you want to delete old directories and files? (y/N) " confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
        rm -rf "/var/lib/${network_container_name}/data/storage/mainnet/*"
        rm -rf "/var/lib/${network_container_name}/data/snapshots/mainnet/*"
        #rm -rf "/var/lib/${network_container_name}/data/p2pstore/mainnet/*"
    else
        echo "Cleanup aborted."
    fi
}

show_logs() {
    docker compose logs -f --tail 1000
}

rename_container() {
    # Common renaming for both networks
    docker container rename "${network_container_name}_hornet_1" "${network_container_name}" >/dev/null 2>&1
    docker container rename "${network_container_name}_traefik_1" "${network_container_name}.traefik" >/dev/null 2>&1
    docker container rename "${network_container_name}_grafana_1" "grafana" >/dev/null 2>&1
    docker container rename "${network_container_name}_prometheus_1" "prometheus" >/dev/null 2>&1

    local services=("inx-participation" "inx-dashboard" "inx-indexer" "inx-poi" "inx-spammer" "inx-mqtt")
    for service in "${services[@]}"; do
        docker container rename "${network_container_name}_${service}_1" "${network_container_name}.${service}" >/dev/null 2>&1
    done

    # Specific renaming for IOTA and Shimmer
    if [ "$network_name" == "iota" ]; then
        docker container rename "iota-wasp_traefik_1" "iota-wasp.traefik" >/dev/null 2>&1
        docker container rename "iota-wasp_wasp_1" "iota-wasp" >/dev/null 2>&1
    else
        docker container rename "shimmer-wasp_traefik_1" "shimmer-wasp.traefik" >/dev/null 2>&1
        docker container rename "shimmer-wasp_wasp_1" "shimmer-wasp" >/dev/null 2>&1
    fi
}

download_snapshot() {
    wget "$url" || { echo "Error downloading snapshot. Exiting."; exit 1; }

    # Convert special characters in the file name
    file_name=$(echo "$url" | sed 's/%3A/:/g')

    # Extract the last part of the file name
    file_name_parts=($(echo "$file_name" | tr '/' ' '))
    file_name_end="${file_name_parts[-1]}"

    mv "$file_name_end" full_snapshot.bin
}

# --- Main script starts here ---

rm snapshot_extension.sh

select_network=$(whiptail --title "Select Network" --radiolist \
"Which network do you want to use?" 20 60 10 \
"IOTA" "Use IOTA network" ON \
"Shimmer" "Use Shimmer network" OFF 3>&1 1>&2 2>&3)

[[ $? -eq 1 ]] && { echo "Cancelled. Exiting program."; exit 0; }

if [ "$select_network" == "IOTA" ]; then
    network_name="iota"
    network_container_name="iota-hornet"
else
    network_name="shimmer"
    network_container_name="shimmer-hornet"
fi

if [ -d "/var/lib/${network_container_name}" ]; then
    cd "/var/lib/${network_container_name}" || { echo "Cannot change directory to /var/lib/${network_container_name}. Exiting."; exit 1; }
    docker-compose down
    cleanup
fi

cd "/var/lib/${network_container_name}/data/snapshots/mainnet/" || { echo "Cannot change directory to /var/lib/${network_container_name}/data/snapshots/mainnet/. Exiting."; exit 1; }

if [ "$network_name" == "iota" ]; then
    url=$(whiptail --title "Download snapshot" --inputbox "\n
Latest IOTA TangleBay - Full Snapshot
https://cdn.tanglebay.com/snapshots/iota-mainnet/full_snapshot.bin
\n
Please enter the snapshot-link:" 20 80 "https://cdn.tanglebay.com/snapshots/iota-mainnet/full_snapshot.bin" 3>&1 1>&2 2>&3)
else
    url=$(whiptail --title "Download snapshot" --inputbox "\n
Latest Shimmer TangleBay - Full Snapshot
https://cdn.tanglebay.com/snapshots/shimmer-mainnet/full_snapshot.bin
\n
Please enter the snapshot-link:" 15 80 "https://cdn.tanglebay.com/snapshots/shimmer-mainnet/full_snapshot.bin" 3>&1 1>&2 2>&3)
fi

[[ $? -eq 1 ]] && { echo "Cancelled. Exiting program."; exit 0; }

download_snapshot

if [ -d "/var/lib/${network_container_name}" ]; then
    cd "/var/lib/${network_container_name}" || { echo "Cannot change directory to /var/lib/${network_container_name}. Exiting."; exit 1; }
    docker-compose up -d || { echo "Error starting containers. Exiting."; exit 1; }
fi

rename_container; sleep 3
show_logs
