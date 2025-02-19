###IMPORTANT###
#Si vous utilisez containerd, assurez-vous que Docker n'est pas installé.
#kubeadm init essaiera de détecter automatiquement le runtime de conteneur et pour le moment
#s'ils sont tous les deux installés, il choisira Docker en premier.

ssh ip_noeudControlPlane

sudo vi /etc/containerd/config.toml

# modifier également de sanbox_image dans ce fichier de configuration
sudo kubeadm config images pull


sudo echo "1" | sudo tee /proc/sys/net/ipv4/ip_forward
sudo vi /etc/sysctl.conf
decommenter la ligne suivante :
net.ipv4.ip_forward=1


#0 - Création d'un Cluster
#Créez notre cluster kubernetes, spécifiez une plage d'adresses réseau pour les pods qui correspond à celle dans calico.yaml!
#Seulement sur le Noeud de Plan de Contrôle, téléchargez les fichiers yaml pour le réseau de pods.
wget https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml


#Regardez à l'intérieur de calico.yaml et trouvez le paramètre pour la plage d'adresses IP du réseau Pod CALICO_IPV4POOL_CIDR,
Permet de configurer la plage d'adresse pour les pods
#ajustez si nécessaire pour votre infrastructure pour vous assurer que la plage d'adresses IP du réseau de pods
#ne se chevauche pas avec d'autres réseaux dans notre infrastructure.
vi calico.yaml


#Vous pouvez maintenant simplement utiliser kubeadm init pour initialiser le cluster
IP=$(hostname -I | awk '{print $2}')
sudo kubeadm init --apiserver-advertise-address=$IP
# sudo kubeadm init --kubernetes-version v1.26.0

#sudo kubeadm init #supprimez le paramètre kubernetes-version si vous voulez utiliser la dernière version.


#Avant de continuer, examinez le résultat du processus de création du cluster, y compris les phases de kubeadm init,
#la configuration admin.conf et la commande de jointure des nœuds


#Configurez notre compte sur le Noeud de Plan de Contrôle pour avoir un accès administrateur au serveur API depuis un compte non privilégié.
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


#1 - Création d'un réseau de Pods
#Déployez le fichier yaml pour votre réseau de pods.
kubectl apply -f calico.yaml


#Recherchez tous les pods système et les pods calico pour qu'ils passent à l'état Running.
#Le pod DNS ne démarrera pas (en attente) tant que le réseau de pods n'est pas déployé et en cours d'exécution.
kubectl get pods --all-namespaces


#Vous donne une sortie dans le temps, plutôt que de repeindre l'écran à chaque itération.
kubectl get pods --all-namespaces --watch


#Tous les pods système doivent être en cours d'exécution
kubectl get pods --all-namespaces


#Obtenez une liste de nos nœuds actuels, juste le Noeud de Plan de Contrôle... il devrait être prêt.
kubectl get nodes


#2 - Unités systemd... encore!
#Vérifiez l'unité systemd... elle ne redémarre plus en boucle car elle a des pods statiques à démarrer
#N'oubliez pas que le kubelet démarre les pods statiques, et donc les pods du plan de contrôle
sudo systemctl status kubelet.service


#3 - Manifestes de Pods statiques
#Examinons les manifestes de pods statiques sur le Noeud de Plan de Contrôle
ls /etc/kubernetes/manifests


#Et regardons de plus près le manifeste de l'API serveur et d'etcd.
sudo more /etc/kubernetes/manifests/etcd.yaml
sudo more /etc/kubernetes/manifests/kube-apiserver.yaml


#Vérifiez le répertoire où se trouvent les fichiers de configuration kube pour chacun des pods du plan de contrôle.
ls /etc/kubernetes
