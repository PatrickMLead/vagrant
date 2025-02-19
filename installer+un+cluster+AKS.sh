# Cette démo sera exécutée depuis controle plane car kubectl y est déjà installé.
# Cela peut être exécuté depuis n'importe quel système ayant le client Azure CLI installé.

# Assurez-vous que les utilitaires de ligne de commande Azure CLI sont installés
# https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | sudo tee /etc/apt/sources.list.d/azure-cli.list

# Installez la clé gpg du dépôt Microsoft
curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null

sudo apt-get update
sudo apt-get install azure-cli

# Connectez-vous à notre abonnement
# Compte gratuit - https://azure.microsoft.com/en-us/free/
az login
az account set --subscription "Azure subscription 1"

# Créez un groupe de ressources pour les services que nous allons créer
az group create --name "Kubernetes-Cloud" --location centralus

# Obtenons une liste des versions disponibles
az aks get-versions --location centralus -o table

# Créez notre cluster géré AKS. Utilisez --kubernetes-version pour spécifier une version.
az aks create \
    --resource-group "Kubernetes-Cloud" \
    --generate-ssh-keys \
    --name AKSCluster \
    --node-count 2 
   

# Si nécessaire, nous pouvons télécharger et installer kubectl sur notre système local.
az aks install-cli

# Obtenez les informations d'identification de notre cluster et fusionnez la configuration dans notre fichier de configuration existant.
# Cela nous permettra de nous connecter à ce système à distance en utilisant l'authentification basée sur des certificats.
az aks get-credentials --resource-group "Kubernetes-Cloud" --name AKSCluster

# Répertoriez les contextes actuellement disponibles
kubectl config get-contexts

# Définissez notre contexte actuel sur le contexte Azure
kubectl config use-context AKSCluster

# Exécutez une commande pour communiquer avec notre cluster.
kubectl get nodes

# Obtenez une liste des pods en cours d'exécution, nous examinerons les pods système car nous n'avons rien d'autre en cours d'exécution.
# Comme le serveur API est basé sur HTTP, nous pouvons exploiter notre cluster sur Internet, essentiellement de la même manière que s'il était local en utilisant kubectl.
kubectl get pods --all-namespaces

# Rétablissons le contexte kubectl sur notre cluster local
kubectl config use-context kubernetes-admin@kubernetes

# Utilisez kubectl get nodes
kubectl get nodes

# az aks delete --resource-group "Kubernetes-Cloud" --name CSCluster #--yes --no-wait
