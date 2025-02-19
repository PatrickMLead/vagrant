#!/bin/bash

## install common for k8s


HOSTNAME=$(hostname)
IP=$(hostname -I | awk '{print $2}')
echo "START - install common - "$IP

echo "[1]: add host name for ip"
host_exist=$(cat /etc/hosts | grep -i "$IP" | wc -l)
if [ "$host_exist" == "0" ];then
echo "$IP $HOSTNAME " >>/etc/hosts
fi

echo "[2]: disable swap"
# swapoff -a to disable swapping
swapoff -a
# sed to comment the swap partition in /etc/fstab
sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab

echo "[3]: initialisation du réseau overlay"

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Paramètres sysctl nécessaires à la configuration, les paramètres persistent après les redémarrages
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Appliquer les paramètres sysctl sans redémarrage
sudo sysctl --system

# Installer containerd... il faut installer depuis le dépôt docker pour obtenir containerd 1.6, le dépôt ubuntu s'arrête à 1.5.9
sudo apt-get install ca-certificates curl >/dev/null
sudo install -m 0755 -d /etc/apt/keyrings >/dev/null
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y containerd.io >/dev/null

sudo containerd config default | sudo tee /etc/containerd/config.toml
# À la fin de cette section, changez SystemdCgroup = false en SystemdCgroup = true
#         [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
#         ...
#           [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
#             SystemdCgroup = true

# Vous pouvez utiliser sed pour remplacer par true
sudo sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml

# modifier également de sanbox_image dans ce fichier de configuration
sudo sed -i 's/ sandbox_image = "registry.k8s.io/pause:3.8"/ sandbox_image = "registry.k8s.io/pause:3.10"/' /etc/containerd/config.toml

# Redémarrez containerd avec la nouvelle configuration
sudo systemctl restart containerd


# Installez les paquets Kubernetes - kubeadm, kubelet et kubectl
# Ajoutez la clé gpg du dépôt apt de Google
sudo curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg

# Ajoutez le dépôt apt de Kubernetes
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg >/dev/null

# If the folder `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# allow unprivileged APT programs to read this keyring

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
# helps tools such as command-not-found to work correctly

# Mettez à jour la liste des paquets et utilisez apt-cache policy pour inspecter les versions disponibles dans le dépôt
sudo apt-get update
apt-cache policy kubelet | head -n 20

# Installez les paquets requis, si nécessaire nous pouvons demander une version spécifique.
# Utilisez cette version car dans un cours ultérieur, nous mettrons à niveau le cluster vers une version plus récente.
# Essayez de choisir une version précédente car plus tard dans cette série, nous effectuerons une mise à niveau
VERSION=1.32.1-1.1
sudo apt-get install -y kubelet=$VERSION kubeadm=$VERSION kubectl=$VERSION >/dev/null
sudo apt-mark hold kubelet kubeadm kubectl containerd
sudo kubeadm config images pull

# Assurez-vous que les deux sont configurés pour démarrer lorsque le système démarre.
sudo systemctl enable kubelet.service
sudo systemctl enable containerd.service

echo "END - install common - " $IP
