
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Install the Docker packages.
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Verify that the installation is successful by running the hello-world image:
sudo docker run hello-world

# Check if helm is installed
if ! command -v helm &> /dev/null
then
    # Install helm
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    sudo apt-get install apt-transport-https --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update
    sudo apt-get install helm
    echo "Helm has been installed."
else
    echo "Helm is already installed."
fi

# add current user in docker group
sudo usermod -aG docker $USER && newgrp docker<<'EOF'

# Check if minikube is installed
if ! command -v minikube &> /dev/null
then
    echo "Minikube could not be found, installing..."

    # minikube Installation
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube

    echo "Minikube has been installed."
else
    echo "Minikube is already installed."
fi

# Check if Minikube is already running
minikube_status=$(minikube status | grep -o "host: Running")

if [ -n "$minikube_status" ]; then
    echo "Minikube is already running."
else
    echo "Minikube is not running. Starting Minikube..."
    # minikube start -p local-cluster --nodes 2 --driver=docker
    minikube start --nodes 2 --driver=docker
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "kubectl is not installed. Installing..."
    
    # Installing  kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    kubectl version --client

    echo "kubectl has been installed."
else
    echo "kubectl is already installed."
fi

# list all nodes
kubectl get nodes

sleep 10

# list all pods
kubectl get po -A
EOF
