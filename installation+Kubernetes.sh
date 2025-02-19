# Configuration
#   1. 4 VMs Ubuntu 22.04, 1 plan de contrôle, 3 nœuds.
#   2. IPs statiques sur les VM individuelles
#   3. Le fichier /etc/hosts comprend les mappages de noms vers IPs pour les VMs
#   4. La swap est désactivée
#   5. Prenez des instantanés avant l'installation, ainsi vous pouvez installer
#       et revenir à l'instantané si nécessaire
#
# ssh ip_controlplanenode

# 0 - Désactivez la swap, utilisez swapoff puis modifiez votre fstab en supprimant toute entrée pour les partitions swap
# Vous pouvez récupérer l'espace avec fdisk. Vous voudrez peut-être redémarrer pour vous assurer que votre configuration est correcte.
sudo swapoff -a
vi /etc/fstab

### IMPORTANT ###
# Je m'attends à ce que ce code change un peu pour rendre le processus d'installation plus fluide.
# Au final, le résultat restera le même... vous aurez containerd installé
# Je maintiendrai le code dans les téléchargements du cours à jour avec la dernière méthode.
#################

# 0 - Installer les paquets
# Prérequis de containerd, chargez deux modules et configurez-les pour qu'ils se chargent au démarrage
# https://kubernetes.io/docs/setup/production-environment/container-runtimes/

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
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y containerd.io

# Créez un fichier de configuration containerd
# sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Définissez le pilote cgroup pour containerd sur systemd, nécessaire pour le kubelet.
# Pour plus d'informations sur ce fichier de configuration, voir :
# https://github.com/containerd/cri/blob/master/docs/config.md et aussi
# https://github.com/containerd/containerd/blob/master/docs/ops.md

# À la fin de cette section, changez SystemdCgroup = false en SystemdCgroup = true
#         [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
#         ...
#           [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
#             SystemdCgroup = true

# Vous pouvez utiliser sed pour remplacer par true
sudo sed -i 's/            SystemdCgroup = false/            SystemdCgroup = true/' /etc/containerd/config.toml

# Vérifiez que le changement a été effectué
sudo vi /etc/containerd/config.toml

# modifier également de sanbox_image dans ce fichier de configuration

# Redémarrez containerd avec la nouvelle configuration
sudo systemctl restart containerd

# Installez les paquets Kubernetes - kubeadm, kubelet et kubectl
# Ajoutez la clé gpg du dépôt apt de Google
sudo curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg

# Ajoutez le dépôt apt de Kubernetes
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

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
sudo apt-get install -y kubelet=$VERSION kubeadm=$VERSION kubectl=$VERSION
sudo apt-mark hold kubelet kubeadm kubectl containerd
sudo kubeadm config images pull


# Pour installer la dernière version, omettez les paramètres de version. J'ai testé toutes les démonstrations avec la version ci-dessus, si vous utilisez la dernière, cela peut affecter d'autres démonstrations dans ce cours et les cours à venir dans la série
# sudo apt-get install kubelet kubeadm kubectl
# sudo apt-mark hold kubelet kubeadm kubectl containerd

# 1 - Unités systemd
# Vérifiez le statut de notre kubelet et de notre runtime de conteneur, containerd.
# Le kubelet entrera dans une boucle de crash jusqu'à ce qu'un cluster soit créé ou que le nœud soit joint à un cluster existant.
sudo systemctl status kubelet.service
sudo systemctl status containerd.service

# Assurez-vous que les deux sont configurés pour démarrer lorsque le système démarre.
sudo systemctl enable kubelet.service
sudo systemctl enable containerd.service
