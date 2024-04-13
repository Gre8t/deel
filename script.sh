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
install_virtualbox(){
  sudo apt update
  sudo apt install virtualbox -y
}
install_prerequisites() {
    sudo -v
    command_exists kubectl && echo "kubectl is already installed." || install_kubectl
    # command_exists docker && echo "docker is already installed" || install_docker
    command_exists minikube && echo "minikube is already installed" || install_minikube
    command_exists helm && echo "Helm is already installed." || install_helm
    command_exists virtualbox && echo "Virtualbox is already installed." || install_virtualbox
    echo "Installation of Docker, kubectl, helm, Minikube and Virtualbox is complete."
}
start_minikube() {
  echo "Starting Minikube cluster..."
  minikube start -p $minikube_profile --driver=virtualbox --cpus=4 --memory=4gb --force --iso-url=https://storage.googleapis.com/minikube/iso/minikube-v1.32.0-amd64.iso
}
install_argo_cd(){
  echo "Installing Argo-CD..."
  helm install argo-cd oci://registry-1.docker.io/bitnamicharts/argo-cd -n argo-cd --create-namespace --namespace argo-cd
}
install_redis() {
  echo "Installing Redis..."
  helm install --create-namespace --namespace redis redis oci://registry-1.docker.io/bitnamicharts/redis -n  $redis_namespace >/dev/null 2>&1 
  echo "Redis Installed!"
}
install_cloudflare_tunnel() {
 kubectl create -f ./manifest.yaml
}
install_falco(){
  helm repo add falcosecurity https://falcosecurity.github.io/charts
  helm repo update
  helm install falco falcosecurity/falco \
    --create-namespace \
    --namespace falco \
    --set falco.grpc.enabled=true \
    --set falco.grpc_output.enabled=true
  helm install falco-exporter falcosecurity/falco-exporter -n falco

}
install_prometheus(){
 helm repo add bitnami https://charts.bitnami.com/bitnami
 helm repo update
 helm install --create-namespace --namespace prometheus prometheus bitnami/kube-prometheus
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
  helm install --create-namespace --namespace staging deel ./deel >/dev/null 2>&1 
  echo "deel installed!"
}

install_prerequisites
start_minikube
install_redis
install_falco
install_prometheus
update_redis_helm_values "redis-master"
install_argo_cd
deploy_helm_chart
install_cloudflare_tunnel
echo "Script execution completed."
