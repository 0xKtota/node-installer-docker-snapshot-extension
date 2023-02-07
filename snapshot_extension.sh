#!/bin/bash

# Remove this script
rm snapshot_extension.sh

# Prompt user to select IOTA or Shimmer
select_network=$(whiptail --title "Select Network" --radiolist \
"Which network do you want to use?" 20 60 10 \
"IOTA" "Use IOTA network" ON \
"Shimmer" "Use Shimmer network" OFF 3>&1 1>&2 2>&3)

# Set variables based on user's selection
if [ "$select_network" == "IOTA" ]; then
  network_name="iota"
  network_container_name="iota-hornet"
else
  network_name="shimmer"
  network_container_name="shimmer-hornet"
fi

show_logs () {
  docker compose logs -f --tail 1000
}

rename_container() {
  docker container rename "${network_container_name}_hornet_1" "${network_container_name}" >/dev/null 2>&1
  docker container rename "${network_container_name}_traefik_1" "${network_container_name}.traefik" >/dev/null 2>&1
}

if [ -d /var/lib/${network_container_name} ]; then
  cd /var/lib/${network_container_name}
  docker-compose down
fi

rm -rf /var/lib/${network_container_name}/data/storage/mainnet/*
rm -rf /var/lib/${network_container_name}/data/snapshots/mainnet/*
rm -rf /var/lib/${network_container_name}/data/p2pstore/mainnet/*

cd /var/lib/${network_container_name}/data/snapshots/mainnet/

if [ "$network_name" == "IOTA" ]; then
  
  url=$(whiptail --title "Download snapshot" --inputbox "IOTA Staking Round 4 - Full Snapshot
  
  https://chrysalis-dbfiles.iota.org/snapshots/hornet/2022-11-04T06%3A14%3A34Z-4784523-full_snapshot.bin

  Please enter the snapshot-link:" 10 80 "https://chrysalis-dbfiles.iota.org/snapshots/hornet/2022-11-04T06%3A14%3A34Z-4784523-full_snapshot.bin" 3>&1 1>&2 2>&3)

else
  url=$(whiptail --title "Download snapshot" --inputbox "Shimmer 07/02/2023 - Full Snapshot
  
  https://files.shimmer.shimmer.network/snapshots/2023-02-06T22%3A40%3A05Z-2284688-full_snapshot.bin

  Please enter the snapshot-link:" 10 80 "https://files.shimmer.shimmer.network/snapshots/2023-02-06T22%3A40%3A05Z-2284688-full_snapshot.bin" 3>&1 1>&2 2>&3)
fi

# Use wget to download the file
wget $url

# Convert special characters in the file name
file_name=$(echo $url | sed 's/%3A/:/g')

# Extract the last part of the file name
file_name_parts=($(echo $file_name | tr '/' ' '))
file_name_end=${file_name_parts[-1]}

# Rename the downloaded file
mv $file_name_end full_snapshot.bin

if [ -d /var/lib/${network_container_name} ]; then
  cd /var/lib/${network_container_name}
  docker-compose up -d
fi

rename_container

show_logs
