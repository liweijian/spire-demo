# SPIRE Demo - Using supasaf.com Domain and Service Accounts

## Project Structure

```
spire-demo/
├── README.md
├── go.mod
├── go.sum
├── setup-spire.sh
├── build.sh
├── deployment.yaml
├── proto/
│   ├── echo.proto
│   ├── echo.pb.go
│   └── echo_grpc.pb.go
├── server/
│   ├── main.go
│   └── Dockerfile
└── client/
    ├── main.go
    └── Dockerfile
```

## Execution Steps

### 1. Initialize the Project

```bash
# Create project directory
mkdir -p spire-demo && cd spire-demo

# Initialize Go module
go mod init spire-demo

# Install necessary tools
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

# Add to PATH (if not already)
export PATH="$PATH:$(go env GOPATH)/bin"
```

### 2. Create the Proto File

Create a file at `proto/echo.proto` with the code provided later.

### 3. Generate Protobuf Code

```bash
# Create proto directory (if not already)
mkdir -p proto

# Generate Go code
protoc --go_out=. --go_opt=paths=source_relative \
    --go-grpc_out=. --go-grpc_opt=paths=source_relative \
    proto/echo.proto

# Download dependencies
go mod tidy
```

### 4. Create All Required Files

Create the following files using the full code provided below:

* `server/main.go`
* `server/Dockerfile`
* `client/main.go`
* `client/Dockerfile`
* `deployment.yaml`
* `setup-spire.sh`
* `build.sh`

### 5. Grant Execute Permissions

```bash
chmod +x setup-spire.sh build.sh
```

### 6. Ensure Minikube Is Running

```bash
minikube status
# If not running, start it
minikube start
```

### 7. Clean Up Any Old SPIRE Installation

```bash
# If SPIRE was previously installed, uninstall it first
helm uninstall spire -n spire-system 2>/dev/null || true
kubectl delete namespace spire-system 2>/dev/null || true

# Wait for cleanup to complete
sleep 10
```

### 8. Install and Configure SPIRE (Using supasaf.com)

```bash
./setup-spire.sh
```

This script will:

* **Install SPIRE via Helm and set the trust domain to `supasaf.com`**
* Wait for SPIRE components to become ready
* Create dedicated Service Accounts
* Register node identity (`spiffe://supasaf.com/minikube-node`)
* Register server identity (using Service Account selector)
* Register client identity (using Service Account selector)

### 9. Build the Application Images

```bash
./build.sh
```

### 10. Deploy the Application

```bash
kubectl apply -f deployment.yaml
```

### 11. Verify the Result

```bash
# Check pod status
kubectl get pods

# View server logs
kubectl logs -l app=my-server -f

# In another terminal, view client logs
kubectl logs -l app=my-client -f
```

## Expected Output

**Server Logs:**

```
ss@ss:~/spire-demo$ kubectl logs -l app=my-server -f
2025/10/06 08:51:24 🚀 Starting server, waiting for SPIRE agent...
2025/10/06 08:51:25 ✅ Successfully connected to SPIRE agent
2025/10/06 08:51:25 🎧 Server listening on :8080 with mTLS enabled
2025/10/06 08:51:25 ✅ Received a request from client with SPIFFE ID: spiffe://supasaf.com/client
2025/10/06 08:51:31 ✅ Received a request from client with SPIFFE ID: spiffe://supasaf.com/client
2025/10/06 08:51:50 ✅ Received a request from client with SPIFFE ID: spiffe://supasaf.com/client
```

**Client Logs:**

```
ss@ss:~/spire-demo$ kubectl logs -l app=my-client -f
2025/10/06 08:51:30 🚀 Starting client, waiting for SPIRE agent...
2025/10/06 08:51:31 ✅ Successfully connected to SPIRE agent
2025/10/06 08:51:31 🔄 Attempting to connect to server (attempt 1/10)...
2025/10/06 08:51:31 ✅ Connected to server
2025/10/06 08:51:31 📤 Sending request to server...
2025/10/06 08:51:31 ✅ Response from server: Hello SPIFFE from spiffe://supasaf.com/client
2025/10/06 08:51:31 🎉 Zero Trust communication successful!
```

## Cleanup

To reset the environment:

```bash
# Delete application deployment
kubectl delete -f deployment.yaml

# Uninstall SPIRE
helm uninstall spire -n spire-system

# Optional: delete the namespace
kubectl delete namespace spire-system
```
