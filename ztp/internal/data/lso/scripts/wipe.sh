# Wipe the disks:
{{ range .Disks -}}
sudo sgdisk --zap-all {{ . }}
sudo dd if=/dev/zero of={{ . }} bs=1M count=100 oflag=direct,dsync
sudo blkdiscard {{ . }}
{{ end -}}

# Remove all volume groups:
sudo dmsetup remove_all