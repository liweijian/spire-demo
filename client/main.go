package main

import (
	"context"
	"log"
	"time"

	"github.com/spiffe/go-spiffe/v2/spiffetls/tlsconfig"
	"github.com/spiffe/go-spiffe/v2/workloadapi"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"

	"spire-demo/proto"
)

func main() {
	ctx := context.Background()

	log.Println("🚀 Starting client, waiting for SPIRE agent...")

	source, err := workloadapi.NewX509Source(ctx)
	if err != nil {
		log.Fatalf("❌ Unable to create X509Source: %v", err)
	}
	defer source.Close()

	log.Println("✅ Successfully connected to SPIRE agent")

	tlsConfig := tlsconfig.MTLSClientConfig(source, source, tlsconfig.AuthorizeAny())
	creds := credentials.NewTLS(tlsConfig)

	var conn *grpc.ClientConn
	maxRetries := 10
	for i := 0; i < maxRetries; i++ {
		log.Printf("🔄 Attempting to connect to server (attempt %d/%d)...", i+1, maxRetries)
		
		dialCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
		conn, err = grpc.DialContext(
			dialCtx,
			"my-server-svc:8080",
			grpc.WithTransportCredentials(creds),
			grpc.WithBlock(),
		)
		cancel()

		if err == nil {
			break
		}

		log.Printf("⚠️  Connection failed: %v", err)
		if i < maxRetries-1 {
			time.Sleep(3 * time.Second)
		}
	}

	if err != nil {
		log.Fatalf("❌ Could not connect after %d attempts: %v", maxRetries, err)
	}
	defer conn.Close()

	log.Println("✅ Connected to server")

	c := proto.NewEchoClient(conn)

	log.Println("📤 Sending request to server...")
	callCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	r, err := c.SayHello(callCtx, &proto.Request{Name: "SPIFFE"})
	if err != nil {
		log.Fatalf("❌ Could not call SayHello: %v", err)
	}

	log.Printf("✅ Response from server: %s", r.Message)
	log.Println("🎉 Zero Trust communication successful!")

	time.Sleep(5 * time.Second)
}
