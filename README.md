# Proxmox-ID-Changer

Willkommen zum Proxmox-ID-Changer! Dieses Skript ermöglicht es Ihnen, die ID eines LXC-Containers (LXC) oder einer Virtuellen-Maschine (VM) auf Ihrem Proxmox-Server zu ändern.

## Funktionen

- Änderung der ID für LXC und QEMU
- Überprüfung und Anpassung der logischen Volumes (LVM)
- Überprüfung und Anpassung der ZFS-Volumes
- Aktualisierung der Konfigurationsdateien

## Installation

1. Klonen Sie dieses Repository auf Ihren Proxmox-Server:
    ```bash
    git clone https://github.com/sakis-tech/Proxmox-ID-Changer.git
    ```
2. Wechseln Sie in das Verzeichnis des Skripts:
    ```bash
    cd Proxmox-ID-Changer
    ```
3. Machen Sie das Skript ausführbar:
    ```bash
    chmod +x proxmox-id-changer.sh
    ```

## Nutzung

1. Starten Sie das Skript:
    ```bash
    ./proxmox-id-changer.sh
    ```
2. Folgen Sie den Anweisungen auf dem Bildschirm:
    - Geben Sie den VM-Typ ein (`lxc` oder `qemu`).
    - Geben Sie die alte VMID ein.
    - Geben Sie die neue VMID ein.

## Beispiel

```text
Willkommen zum VMID-Änderungsskript.
Dieses Skript ändert die VMID eines virtuellen Containers (lxc) oder eines QEMU-Servers (qemu).

Bitte geben Sie den VM-Typ ein, den Sie ändern möchten (lxc, qemu):
lxc

Bitte geben Sie die alte VMID ein:
101

Bitte geben Sie die neue VMID ein:
102

Überprüfe logische Volumes für VMID 101...
Logische Volumes Ausgabe:
...

Volume Group: pve
Benenne Volume vm-101-disk-0 zu vm-102-disk-0 um
...

Überprüfe ZFS-Volumes für VMID 101...
ZFS-Ausgabe:
...

Benenne ZFS-Volume vm-101-disk-0 zu vm-102-disk-0 um
...

Aktualisiere Konfigurationsdateien...
Fertig!

```

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Weitere Informationen finden Sie in der LICENSE Datei.

## Beitrag

Beiträge sind willkommen! Bitte öffnen Sie ein Issue, bevor Sie eine Pull-Request einreichen.
