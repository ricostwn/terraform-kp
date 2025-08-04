#!/bin/bash

# Step 1: Tambahkan GPG key HashiCorp
echo "[+] Menambahkan GPG key HashiCorp..."
wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

# Step 2: Verifikasi fingerprint (opsional)
echo "[+] Verifikasi fingerprint GPG..."
gpg --no-default-keyring \
--keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
--fingerprint

# Step 3: Tambahkan repository HashiCorp ke sources list
echo "[+] Menambahkan repository HashiCorp ke sources.list.d..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Step 4: Update package index
echo "[+] Menjalankan apt update..."
sudo apt update

# Step 5: Install Terraform
echo "[+] Menginstall Terraform..."
sudo apt-get install -y terraform

# Memastikan .bashrc ada di home directory
if [ ! -f "$HOME/.bashrc" ]; then
  echo "[!] File .bashrc tidak ditemukan di home directory. Membuat file baru..."
  touch "$HOME/.bashrc"
fi

# Step 6: Install terraform autocompletion
echo "[+] Menginstall autocompletion untuk Terraform..."
terraform -install-autocomplete

echo "[✓] Instalasi selesai. Cek versi dengan 'terraform -v'"
