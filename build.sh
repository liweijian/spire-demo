#!/bin/bash
set -e

echo "🏗️  Building SPIRE Demo..."

echo "📋 Checking Go version..."
go version

if [ ! -f "proto/echo.pb.go" ]; then
    echo "📝 Generating protobuf code..."
    protoc --go_out=. --go_opt=paths=source_relative \
        --go-grpc_out=. --go-grpc_opt=paths=source_relative \
        proto/echo.proto
    echo "✅ Protobuf code generated"
fi

echo "📦 Tidying Go modules..."
go mod tidy

echo "🐳 Switching to minikube Docker..."
eval $(minikube -p minikube docker-env)

echo "🔨 Building server image..."
docker build -f server/Dockerfile -t my-server:latest . || {
    echo "❌ Server build failed!"
    exit 1
}
echo "✅ Server image built"

echo "🔨 Building client image..."
docker build -f client/Dockerfile -t my-client:latest . || {
    echo "❌ Client build failed!"
    exit 1
}
echo "✅ Client image built"

echo ""
echo "📦 Built images:"
docker images | grep -E "my-server|my-client"

echo ""
echo "✅ Build complete!"
echo ""
echo "Next steps:"
echo "1. Deploy: kubectl apply -f deployment.yaml"
echo "2. Check: kubectl get pods"
