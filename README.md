# SPIRE Demo - 使用 supasaf.com 域名和 Service Account

## 项目结构
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

## 执行步骤

### 1. 初始化项目
```bash
# 创建项目目录
mkdir -p spire-demo && cd spire-demo

# 初始化 Go module
go mod init spire-demo

# 安装必要的工具
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

# 添加到 PATH（如果还没有）
export PATH="$PATH:$(go env GOPATH)/bin"
```

### 2. 创建 proto 文件
创建 `proto/echo.proto`，内容见下方代码文件。

### 3. 生成 protobuf 代码
```bash
# 创建 proto 目录（如果还没有）
mkdir -p proto

# 生成 Go 代码
protoc --go_out=. --go_opt=paths=source_relative \
    --go-grpc_out=. --go-grpc_opt=paths=source_relative \
    proto/echo.proto

# 下载依赖
go mod tidy
```

### 4. 创建所有必要的文件
按照下面提供的完整代码创建以下文件：
- `server/main.go`
- `server/Dockerfile`
- `client/main.go`
- `client/Dockerfile`
- `deployment.yaml`
- `setup-spire.sh`
- `build.sh`

### 5. 赋予脚本执行权限
```bash
chmod +x setup-spire.sh build.sh
```

### 6. 确保 minikube 正在运行
```bash
minikube status
# 如果没有运行，启动它
minikube start
```

### 7. 清理旧的 SPIRE 安装（如果存在）
```bash
# 如果之前安装过 SPIRE，需要先卸载
helm uninstall spire -n spire-system 2>/dev/null || true
kubectl delete namespace spire-system 2>/dev/null || true

# 等待清理完成
sleep 10
```

### 8. 安装和配置 SPIRE（使用 supasaf.com）
```bash
./setup-spire.sh
```

这个脚本会：
- **使用 Helm 安装 SPIRE 并设置信任域为 `supasaf.com`**
- 等待 SPIRE 组件就绪
- 创建专用的 Service Accounts
- 注册节点身份（使用 `spiffe://supasaf.com/minikube-node`）
- 注册服务端身份（使用 Service Account selector）
- 注册客户端身份（使用 Service Account selector）

### 8. 构建应用镜像
```bash
./build.sh
```

### 9. 部署应用
```bash
kubectl apply -f deployment.yaml
```

### 10. 验证结果
```bash
# 查看 Pod 状态
kubectl get pods

# 查看服务端日志
kubectl logs -l app=my-server -f

# 在另一个终端查看客户端日志
kubectl logs -l app=my-client -f
```

## 预期结果

**服务端日志：**
```
ss@ss:~/spire-demo$ kubectl logs -l app=my-server -f
2025/10/06 08:51:24 🚀 Starting server, waiting for SPIRE agent...
2025/10/06 08:51:25 ✅ Successfully connected to SPIRE agent
2025/10/06 08:51:25 🎧 Server listening on :8080 with mTLS enabled
2025/10/06 08:51:25 ✅ Received a request from client with SPIFFE ID: spiffe://supasaf.com/client
2025/10/06 08:51:31 ✅ Received a request from client with SPIFFE ID: spiffe://supasaf.com/client
2025/10/06 08:51:50 ✅ Received a request from client with SPIFFE ID: spiffe://supasaf.com/client
```

**客户端日志：**
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

## 清理环境

如果需要重新开始：
```bash
# 删除应用部署
kubectl delete -f deployment.yaml

# 删除 SPIRE
helm uninstall spire -n spire-system

# 可选：删除整个 namespace
kubectl delete namespace spire-system
```
