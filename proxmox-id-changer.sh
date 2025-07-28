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

# Überprüfen, ob die VM läuft
if qm status "$OLD_VMID" 2>/dev/null | grep -q running || pct status "$OLD_VMID" 2>/dev/null | grep -q running; then
    echo -e "${RED}Fehler: Die VM mit der ID $OLD_VMID läuft noch. Bitte stoppen Sie sie zuerst.${NC}"
    exit 1
fi

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

# Überprüfen, ob die neue VMID bereits existiert
if [ -f "/etc/pve/$VM_TYPE/$NEW_VMID.conf" ]; then
    echo -e "${RED}Fehler: Eine VM mit der ID $NEW_VMID existiert bereits.${NC}"
    exit 1
fi

echo -e "${GREEN}Neue VMID: $NEW_VMID${NC}"
echo

# Debug-Ausgabe für Logical Volumes
echo -e "${YELLOW}Überprüfe logische Volumes für VMID $OLD_VMID...${NC}"
lvs_output=$(lvs --noheadings -o lv_name,vg_name 2>/dev/null || echo "Keine LVM gefunden")
echo -e "${GREEN}Logische Volumes Ausgabe:${NC}"
echo "$lvs_output"

# Suche nach Volume Group
VG_NAME=$(echo "$lvs_output" | grep -E "vm-$OLD_VMID-disk" | awk '{print $2}' | uniq)

if [ -z "$VG_NAME" ]; then
  echo -e "${YELLOW}Keine LVM-Volumes gefunden für VMID $OLD_VMID. Überprüfe ZFS-Volumes...${NC}"
else
  echo -e "${GREEN}Volume Group: $VG_NAME${NC}"
  for volume in $(lvs --noheadings -o lv_name,vg_name | grep "$VG_NAME" | grep "vm-$OLD_VMID-disk" | awk '{print $1}'); do
    newVolume="${volume//"${OLD_VMID}"/"${NEW_VMID}"}"
    echo -e "${YELLOW}Benenne Volume $volume zu $newVolume um${NC}"
    if ! lvrename "$VG_NAME" "$volume" "$newVolume"; then
      echo -e "${RED}Fehler beim Umbenennen von $volume zu $newVolume${NC}"
      exit 1
    fi
  done
fi

echo -e "${YELLOW}Überprüfe ZFS-Volumes für VMID $OLD_VMID...${NC}"
zfs_output=$(zfs list -t all 2>/dev/null || echo "Keine ZFS gefunden")
echo -e "${GREEN}ZFS-Ausgabe:${NC}"
echo "$zfs_output"

# ZFS-Volumes umbenennen
zfs_volumes=$(echo "$zfs_output" | grep -E "vm-${OLD_VMID}-disk|subvol-${OLD_VMID}-disk" | awk '{print $1}')
if [ -n "$zfs_volumes" ]; then
  for volume in $zfs_volumes; do
    newVolume="${volume//"${OLD_VMID}"/"${NEW_VMID}"}"
    echo -e "${YELLOW}Benenne ZFS-Volume $volume zu $newVolume um${NC}"
    if ! zfs rename "$volume" "$newVolume"; then
      echo -e "${RED}Fehler beim Umbenennen von $volume zu $newVolume${NC}"
      exit 1
    fi
  done
else
  echo -e "${YELLOW}Keine ZFS-Volumes für VMID $OLD_VMID gefunden.${NC}"
fi

# NEU: qcow2-Dateien auf lokalem Speicher umbenennen
echo -e "${YELLOW}Überprüfe qcow2-Dateien für VMID $OLD_VMID...${NC}"

# Standardpfade für Proxmox-Speicher
STORAGE_PATHS=("/var/lib/vz/images" "/var/lib/vz/private")

for storage_path in "${STORAGE_PATHS[@]}"; do
    if [ -d "$storage_path/$OLD_VMID" ]; then
        echo -e "${GREEN}Gefunden: $storage_path/$OLD_VMID${NC}"
        
        # Neues Verzeichnis erstellen falls nicht vorhanden
        if [ ! -d "$storage_path/$NEW_VMID" ]; then
            mkdir -p "$storage_path/$NEW_VMID"
        fi
        
        # Alle Dateien im alten VMID-Verzeichnis umbenennen
        for old_file in "$storage_path/$OLD_VMID"/*; do
            if [ -f "$old_file" ]; then
                filename=$(basename "$old_file")
                new_filename="${filename//"vm-${OLD_VMID}"/"vm-${NEW_VMID}"}"
                new_file="$storage_path/$NEW_VMID/$new_filename"
                
                echo -e "${YELLOW}Verschiebe $old_file zu $new_file${NC}"
                if ! mv "$old_file" "$new_file"; then
                    echo -e "${RED}Fehler beim Verschieben von $old_file zu $new_file${NC}"
                    exit 1
                fi
            fi
        done
        
        # Altes Verzeichnis löschen falls leer
        if [ -d "$storage_path/$OLD_VMID" ] && [ -z "$(ls -A "$storage_path/$OLD_VMID")" ]; then
            rmdir "$storage_path/$OLD_VMID"
            echo -e "${GREEN}Altes Verzeichnis $storage_path/$OLD_VMID gelöscht${NC}"
        fi
    fi
done

# Zusätzlich: Suche nach qcow2-Dateien in allen lokalen Speicherpfaden
echo -e "${YELLOW}Suche nach weiteren qcow2-Dateien...${NC}"
find /var/lib/vz -name "*vm-${OLD_VMID}-disk*" -type f 2>/dev/null | while read -r old_file; do
    dir=$(dirname "$old_file")
    filename=$(basename "$old_file")
    new_filename="${filename//"vm-${OLD_VMID}"/"vm-${NEW_VMID}"}"
    new_file="$dir/$new_filename"
    
    echo -e "${YELLOW}Gefunden: $old_file -> $new_file${NC}"
    if ! mv "$old_file" "$new_file"; then
        echo -e "${RED}Fehler beim Umbenennen von $old_file zu $new_file${NC}"
        exit 1
    fi
done

echo -e "${YELLOW}Aktualisiere Konfigurationsdateien...${NC}"
if [ ! -f "/etc/pve/$VM_TYPE/$OLD_VMID.conf" ]; then
  echo -e "${RED}Konfigurationsdatei /etc/pve/$VM_TYPE/$OLD_VMID.conf nicht gefunden.${NC}"
  exit 1
fi

# Konfigurationsdatei aktualisieren
sed -i "s/$OLD_VMID/$NEW_VMID/g" "/etc/pve/$VM_TYPE/$OLD_VMID.conf"
if ! mv "/etc/pve/$VM_TYPE/$OLD_VMID.conf" "/etc/pve/$VM_TYPE/$NEW_VMID.conf"; then
  echo -e "${RED}Fehler beim Umbenennen der Konfigurationsdatei.${NC}"
  exit 1
fi

echo -e "${GREEN}Die VMID wurde erfolgreich von $OLD_VMID zu $NEW_VMID geändert.${NC}"
echo -e "${YELLOW}Sie müssen gegebenenfalls die Proxmox-Weboberfläche neu laden, um die Änderungen zu sehen.${NC}"
