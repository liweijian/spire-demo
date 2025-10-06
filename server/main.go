package main

import (
	"context"
	"log"
	"net"

	"github.com/spiffe/go-spiffe/v2/spiffetls/tlsconfig"
	"github.com/spiffe/go-spiffe/v2/workloadapi"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/peer"

	"spire-demo/proto"
)

type Server struct {
	proto.UnimplementedEchoServer
}

func (s *Server) SayHello(ctx context.Context, in *proto.Request) (*proto.Response, error) {
	p, ok := peer.FromContext(ctx)
	if !ok {
		log.Printf("Error: could not get peer from context")
		return &proto.Response{Message: "ERROR: no peer info"}, nil
	}

	tlsInfo, ok := p.AuthInfo.(credentials.TLSInfo)
	if !ok {
		log.Printf("Error: peer auth info is not TLS")
		return &proto.Response{Message: "ERROR: no TLS info"}, nil
	}

	if len(tlsInfo.State.PeerCertificates) == 0 {
		log.Printf("Error: no peer certificates")
		return &proto.Response{Message: "ERROR: no certificates"}, nil
	}

	cert := tlsInfo.State.PeerCertificates[0]
	if len(cert.URIs) == 0 {
		log.Printf("Error: no URIs in certificate")
		return &proto.Response{Message: "ERROR: no SPIFFE ID"}, nil
	}

	spiffeID := cert.URIs[0].String()
	log.Printf("✅ Received a request from client with SPIFFE ID: %s", spiffeID)
	
	return &proto.Response{Message: "Hello " + in.Name + " from " + spiffeID}, nil
}

func main() {
	ctx := context.Background()

	log.Println("🚀 Starting server, waiting for SPIRE agent...")

	source, err := workloadapi.NewX509Source(ctx)
	if err != nil {
		log.Fatalf("❌ Unable to create X509Source: %v", err)
	}
	defer source.Close()

	log.Println("✅ Successfully connected to SPIRE agent")

	tlsConfig := tlsconfig.MTLSServerConfig(source, source, tlsconfig.AuthorizeAny())
	creds := credentials.NewTLS(tlsConfig)

	server := grpc.NewServer(grpc.Creds(creds))
	proto.RegisterEchoServer(server, &Server{})

	lis, err := net.Listen("tcp", ":8080")
	if err != nil {
		log.Fatalf("❌ Failed to listen: %v", err)
	}

	log.Println("🎧 Server listening on :8080 with mTLS enabled")
	if err := server.Serve(lis); err != nil {
		log.Fatalf("❌ Failed to serve: %v", err)
	}
}
