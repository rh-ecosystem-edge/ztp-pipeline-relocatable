# Install the CA:
cat >"${HOME}/registry-ca.crt" <<.
{{ .CA }}
.
sudo mv "${HOME}/registry-ca.crt" "/etc/pki/ca-trust/source/anchors"
sudo update-ca-trust

# Restart the services:
sudo systemctl restart crio kubelet