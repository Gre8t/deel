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
  helm install argo-cd oci://registry-1.docker.io/bitnamicharts/argo-cd -n argo-cd --create-namespace --namespace argo-cd --set server.extraArgs[0]="--insecure"
}
install_redis() {
  echo "Installing Redis..."
  helm install --create-namespace --namespace redis redis oci://registry-1.docker.io/bitnamicharts/redis -n  $redis_namespace >/dev/null 2>&1 
  echo "Redis Installed!"
}
install_cloudflare_tunnel() {
 kubectl create -f ./manifest.yml
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
replicate_redis_secret(){
  kubectl apply -f https://github.com/emberstack/kubernetes-reflector/releases/latest/download/reflector.yaml
  kubectl patch secret redis -n redis -p '{"metadata": {"annotations": {"reflector.v1.k8s.emberstack.com/reflection-allowed": "true", "reflector.v1.k8s.emberstack.com/reflection-auto-enabled": "true", "reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces": "staging"}}}'

}
deploy_helm_chart() {
  helm install --create-namespace --namespace staging deel ./deel >/dev/null 2>&1  
  echo "deel installed!"
}
get_argocd_password(){
  echo -e "sleeping for 5 minutes to get everything ready...\n"
  sleep 300
  echo -e "woken up! \n"
  echo -e "Visit http://ci.greatnessdomain.xyz and use the following login credentials: \nUsername: admin \nPassword: $(kubectl get secret -n argo-cd argocd-secret -o jsonpath="{.data.clearPassword}" | base64 -d)"
  echo -e "\nif link is not live, wait an additional 5 mins...\n"
}

install_prerequisites
start_minikube
install_redis
install_falco
install_prometheus
replicate_redis_secret
install_argo_cd
kubectl create ns staging
install_cloudflare_tunnel
get_argocd_password
deploy_helm_chart
echo "done with deel"
echo -e "Visit http://deel.greatnessdomain.xyz to see the deel application running.\n\n"
echo "Script execution completed."