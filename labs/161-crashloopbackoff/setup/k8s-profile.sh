# Acceso a Kubernetes del lab para cualquier usuario.
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
alias k=kubectl
if [ -n "${BASH_VERSION:-}" ] && command -v kubectl >/dev/null; then
  source <(kubectl completion bash 2>/dev/null) 2>/dev/null
  complete -o default -F __start_kubectl k 2>/dev/null
fi
