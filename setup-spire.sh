#!/bin/bash
set -e

KUBECTL="minikube kubectl --"

echo "🚀 Setting up SPIRE demo environment..."

echo "👤 Creating Service Accounts..."
$KUBECTL apply -f - << ENDSA
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-server-sa
  namespace: default
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-client-sa
  namespace: default
ENDSA

echo "📦 Installing SPIRE with Helm..."
helm repo add spiffe https://spiffe.github.io/helm-charts/ 2>/dev/null || true
helm repo update

echo "📦 Installing SPIRE with custom values..."
if helm list -n spire-system | grep -q spire; then
    echo "⚠️  SPIRE already installed, upgrading with custom values..."
    helm upgrade spire spiffe/spire \
        --namespace spire-system \
        -f spire-values.yaml \
        --wait \
        --timeout 5m
else
    helm install spire spiffe/spire \
        --namespace spire-system \
        --create-namespace \
        -f spire-values.yaml \
        --wait \
        --timeout 5m
fi

echo "⏳ Waiting for SPIRE components to be ready..."
$KUBECTL wait --for=condition=ready pod -l app.kubernetes.io/name=server -n spire-system --timeout=300s
$KUBECTL wait --for=condition=ready pod -l app.kubernetes.io/name=agent -n spire-system --timeout=300s

SERVER_POD=$($KUBECTL get pod -n spire-system -l app.kubernetes.io/name=server -o jsonpath='{.items[0].metadata.name}')
echo "✅ SPIRE Server pod: $SERVER_POD"

echo "🔐 Registering node identity..."
$KUBECTL exec -n spire-system $SERVER_POD -c spire-server -- \
    /opt/spire/bin/spire-server entry create \
    -node \
    -spiffeID spiffe://supasaf.com/minikube-node \
    -selector k8s_psat:cluster:minikube \
    -selector k8s_psat:agent_ns:spire-system \
    -selector k8s_psat:agent_sa:spire-agent 2>/dev/null || echo "⚠️  Node entry already exists"

echo "🔐 Registering server workload identity..."
$KUBECTL exec -n spire-system $SERVER_POD -c spire-server -- \
    /opt/spire/bin/spire-server entry create \
    -parentID spiffe://supasaf.com/minikube-node \
    -spiffeID spiffe://supasaf.com/server \
    -selector k8s:ns:default \
    -selector k8s:sa:my-server-sa 2>/dev/null || echo "⚠️  Server entry already exists"

echo "🔐 Registering client workload identity..."
$KUBECTL exec -n spire-system $SERVER_POD -c spire-server -- \
    /opt/spire/bin/spire-server entry create \
    -parentID spiffe://supasaf.com/minikube-node \
    -spiffeID spiffe://supasaf.com/client \
    -selector k8s:ns:default \
    -selector k8s:sa:my-client-sa 2>/dev/null || echo "⚠️  Client entry already exists"

echo ""
echo "📋 Registered entries:"
$KUBECTL exec -n spire-system $SERVER_POD -c spire-server -- \
    /opt/spire/bin/spire-server entry show

echo ""
echo "✅ SPIRE setup complete!"
echo ""
echo "📝 Registered SPIFFE IDs:"
echo "   Node:   spiffe://supasaf.com/minikube-node"
echo "   Server: spiffe://supasaf.com/server (SA: my-server-sa)"
echo "   Client: spiffe://supasaf.com/client (SA: my-client-sa)"
echo ""
echo "Next steps:"
echo "1. Build: ./build.sh"
echo "2. Deploy: kubectl apply -f deployment.yaml"
echo "3. Check logs: kubectl logs -l app=my-server -f"
