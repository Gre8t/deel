#!/bin/bash
set -eu

minikube_profile=deel
redis_namespace=redis

command_exists() {
  command -v "$1" >/dev/null 2>&1
}
install_kubectl() {  
  echo "Installing kubectl..."
  case "$(uname -s)" in
    Linux*)
      sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      sudo install -o $USER -g root -m 0755 kubectl /usr/local/bin/kubectl
      kubectl version --client
      ;;
    Darwin*)
      brew install kubectl
      ;;
    *)
      echo "Unsupported operating system. Please install kubectl manually."
      exit 1
      ;;
  esac
}
install_minikube() {
  
  echo "Installing Minikube..."  
    case "$(uname -s)" in
      Linux*)
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
        rm minikube-linux-amd64
        ;;
      Darwin*)
        brew install minikube
        ;;
      *)
        echo "Unsupported operating system. Please install Minikube manually."
        exit 1
        ;;
    esac
  
}
install_docker(){
  echo "Installing Docker..."
   case "$(uname -s)" in
        Linux*)
            echo "Installing Docker..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh
            sudo systemctl start docker
            sudo systemctl enable docker
            usermod -aG docker $USER

            ;;
        Darwin*)
            if ! command -v brew >/dev/null 2>&1; then
                echo "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi

            echo "Installing Docker for macOS..."
            brew install --cask docker
            ;;
        *)
            echo "Unsupported operating system."
            exit 1
            ;;
    esac
  echo "Please log out and log back in for group changes to take effect."
  exit 0

}
install_prerequisites() {
    sudo -v
    command_exists kubectl && echo "kubectl is already installed." || install_kubectl
    command_exists docker && echo "docker is already installed" || install_docker
    command_exists minikube && echo "minikube is already installed" || install_minikube
    command_exists helm && echo "Helm is already installed." || install_helm
    echo "Installation of Docker, kubectl, helm, and Minikube is complete."
}
start_minikube() {
  echo "Starting Minikube cluster..."
  minikube start -p $minikube_profile --force
}
install_cert_manager() {
  echo "Installing Cert Manager..."
  kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/latest/download/cert-manager.yaml
}
install_argo_cd(){
  echo "Installing Argo-CD..."
  kubectl create ns argo-cd
  helm install argo-cd oci://registry-1.docker.io/bitnamicharts/argo-cd -n argo-cd
}
install_redis() {
  check_namespace $redis_namespace
  echo "Installing Redis..."
  helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1 
  helm repo update >/dev/null 2>&1 
  helm install redis oci://registry-1.docker.io/bitnamicharts/redis -n  $redis_namespace >/dev/null 2>&1 
  echo "Redis Installed!"
}
install_nginx() {
  check_namespace nginx
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 
  helm repo update >/dev/null 2>&1 
  helm install my-ingress-nginx ingress-nginx/ingress-nginx -n nginx >/dev/null 2>&1 
  echo "Nginx Controller installed!"
} 
check_namespace() {
  local namespace="$1"
  kubectl get namespace "$namespace" >/dev/null 2>&1 && echo "Namespace $namespace already exists." || kubectl create namespace "$namespace"
}
install_helm() {
  echo "Installing Helm..."
  case "$(uname -s)" in
    Linux*)
      curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
      chmod +x get_helm.sh
      ./get_helm.sh
      rm get_helm.sh
      ;;
    Darwin*)
      brew install helm
      ;;
    *)
      echo "Unsupported operating system. Please install Helm manually."
      exit 1
      ;;
  esac
}
update_redis_helm_values() {
  local service_name="$1"
  local redis_dns="${service_name}.${redis_namespace}.svc.cluster.local"
  echo "Updating Helm chart values.yaml with Redis DNS: $redis_dns ..."
  awk -v redis_dns="$redis_dns" '/redis_host:/ {$2=redis_dns} 1' deel/values.yaml > tmp.yaml && mv tmp.yaml deel/values.yaml

  local redis_password=$(kubectl get secret -n $redis_namespace redis -o jsonpath="{.data.redis-password}")
  echo "Updating Helm chart values.yaml with Redis password..."
  awk -v redis_password="$redis_password" '/redis_password:/ {$2=redis_password} 1' deel/values.yaml > tmp.yaml && mv tmp.yaml deel/values.yaml
}
deploy_helm_chart() {
  namespace=staging
  check_namespace $namespace
  helm install deel ./deel -n $namespace >/dev/null 2>&1 
  echo "deel installed!"
}
create_minikube_tunnel() {
  echo "Creating minikube tunnel"
  minikube tunnel -p $minikube_profile >/dev/null 2>&1 & disown
}
update_hosts_file() {
  sudo -v
  echo "Waiting to get ip address of deel-app.local" 
  sleep 150
  local domain="deel-app.local"
  local ip=$(kubectl get ingress deel-ingress -n staging -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  if grep -q " $domain" /etc/hosts; then
    # remove entry
    sudo sed -i "/ $domain/d" /etc/hosts
    echo "Entry removed for domain: $domain"
    echo "$ip $domain" | sudo tee -a /etc/hosts > /dev/null
    echo "Entry added: $ip $domain"
  else
    echo "$ip $domain" | sudo tee -a /etc/hosts > /dev/null
    echo "Entry added: $ip $domain"
  fi

  echo -e "Now you can visit \e[34mhttp://deel-app.local\e[0m on your local browser"
}

# Main script execution
install_prerequisites
start_minikube
install_redis
update_redis_helm_values "redis-master"
create_minikube_tunnel 
install_nginx
install_cert_manager
install_argo_cd
sleep 100
deploy_helm_chart
update_hosts_file
echo "Script execution completed."
