#!/usr/bin/env bash

# Farbdefinitionen
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Begrüßung und Beschreibung
echo -e "${GREEN}Willkommen zum VMID-Änderungsskript.${NC}"
echo -e "${YELLOW}Dieses Skript ändert die VMID eines virtuellen Containers (lxc) oder eines QEMU-Servers (qemu).${NC}"
echo

# VM-Typ wählen
echo -e "${YELLOW}Bitte geben Sie den VM-Typ ein, den Sie ändern möchten (lxc, qemu):${NC}"
read -r VM_TYPE

case "$VM_TYPE" in
  "lxc") VM_TYPE="lxc" ;;
  "qemu") VM_TYPE="qemu-server" ;;
  *)
    echo -e "${RED}Falsche Eingabe. Das Skript wird beendet.${NC}"
    exit
    ;;
esac

echo

# Alte VMID eingeben
echo -e "${YELLOW}Bitte geben Sie die alte VMID ein:${NC}"
read -r OLD_VMID

case $OLD_VMID in
  '' | *[!0-9]*)
    echo -e "${RED}Falsche Eingabe. Das Skript wird beendet.${NC}"
    exit
    ;;
  *)
    echo -e "${GREEN}Alte VMID: $OLD_VMID${NC}"
    ;;
esac

echo

# Neue VMID eingeben
echo -e "${YELLOW}Bitte geben Sie die neue VMID ein:${NC}"
read -r NEW_VMID

case $NEW_VMID in
  '' | *[!0-9]*)
    echo -e "${RED}Falsche Eingabe. Das Skript wird beendet.${NC}"
    exit
    ;;
  *)
    echo -e "${GREEN}Neue VMID: $NEW_VMID${NC}"
    ;;
esac

echo

# Debug-Ausgabe für Logical Volumes
echo -e "${YELLOW}Überprüfe logische Volumes für VMID $OLD_VMID...${NC}"
lvs_output=$(lvs --noheadings -o lv_name,vg_name)
echo -e "${GREEN}Logische Volumes Ausgabe:${NC}"
echo "$lvs_output"

# Suche nach Volume Group
VG_NAME=$(echo "$lvs_output" | grep -E "\s$OLD_VMID\b" | awk '{print $2}' | uniq)

if [ -z "$VG_NAME" ]; then
  echo -e "${YELLOW}Keine LVM-Volumes gefunden für VMID $OLD_VMID. Überprüfe ZFS-Volumes...${NC}"
else
  echo -e "${GREEN}Volume Group: $VG_NAME${NC}"
  for volume in $(lvs -a | grep "$VG_NAME" | awk '{print $1}' | grep "$OLD_VMID"); do
    newVolume="${volume//"${OLD_VMID}"/"${NEW_VMID}"}"
    echo -e "${YELLOW}Benenne Volume $volume zu $newVolume um${NC}"
    lvrename "$VG_NAME" "$volume" "$newVolume"
  done
fi

echo -e "${YELLOW}Überprüfe ZFS-Volumes für VMID $OLD_VMID...${NC}"
zfs_output=$(zfs list -t all)
echo -e "${GREEN}ZFS-Ausgabe:${NC}"
echo "$zfs_output"

# ZFS-Volumes umbenennen
for volume in $(echo "$zfs_output" | awk '{print $1}' | grep -E "vm-${OLD_VMID}-disk|subvol-${OLD_VMID}-disk"); do
  newVolume="${volume//"${OLD_VMID}"/"${NEW_VMID}"}"
  echo -e "${YELLOW}Benenne ZFS-Volume $volume zu $newVolume um${NC}"
  zfs rename "$volume" "$newVolume"
done

echo -e "${YELLOW}Aktualisiere Konfigurationsdateien...${NC}"
sed -i "s/$OLD_VMID/$NEW_VMID/g" /etc/pve/"$VM_TYPE"/"$OLD_VMID".conf
mv /etc/pve/"$VM_TYPE"/"$OLD_VMID".conf /etc/pve/"$VM_TYPE"/"$NEW_VMID".conf

echo -e "${GREEN}Fertig!${NC}"
