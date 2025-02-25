# frozen_string_literal: true

require 'rack'
require "grpc"
require "net/http"
require "google/protobuf"
require 'logger'
require 'json'
require_relative "pact_grpc_ruby/version"

module PactGrpcRuby
  LOGGER = Logger.new(STDOUT)
  LOGGER.level = Logger::INFO

  def self.mock_server(service, url = 'localhost:50051', pact_port = 1234)
    server = GRPC::RpcServer.new
    server.add_http2_port(url, :this_port_is_insecure)
    server.handle(service::Service)
    Thread.new do
      server.run_till_terminated_or_interrupted([Signal::INT, Signal::TERM])
    end
    {
      client: service::Stub.new(url, :this_channel_is_insecure, interceptors: [PactGrpcInterceptor.new(pact_port)]),
      server: server
    }
  end

  class PactGrpcInterceptor < GRPC::ClientInterceptor
    def initialize(pact_port)
      @pact_port = pact_port
    end
  
    def request_response(request:, call:, method:, metadata:)
      # Convert the gRPC request to JSON
      json_request = request.to_json
  
      # Construct the HTTP request to send to Pact
      http_request = Net::HTTP::Post.new("/pact/#{method.split('/').last.gsub(/([a-z])([A-Z])/, '\1_\2').downcase}")
      http_request.body = json_request
      http_request['Content-Type'] = 'application/json'

      # Send the HTTP request to the Pact server using the dynamic port
      LOGGER.info("Request body: #{http_request.body}")
      response = Net::HTTP.start('localhost', @pact_port) do |http|
        http.request(http_request)
      end
  
      # Log the response code
      LOGGER.info("Pact interaction sent: #{response.code}")
  
      # Yield to continue the gRPC call
      yield if block_given?
    rescue StandardError => e
      LOGGER.error("Error sending Pact interaction: #{e.message}")
      raise
    end
  end

  class PactGrpcMiddleware
    def initialize(grpc_service_stub)
      @grpc_service_stub = grpc_service_stub
    end
  
    def call(env)
      request = Rack::Request.new(env)
      grpc_action = request.path_info.split('/').last
  
      # Convert JSON to Proto
      proto_class = Object.const_get(grpc_action)
      proto_request = proto_class.decode_json(request.body.read)
  
      # Invoke the gRPC call
      response = @grpc_service_stub.new(grpc_action, :this_channel).call(proto_request)
  
      # Serialize the gRPC response into JSON
      [200, { 'Content-Type' => 'application/json' }, [response.to_json]]
    rescue StandardError => e
      LOGGER.error("Error processing request for #{grpc_action}: #{e.message}")
      [500, { 'Content-Type' => 'application/json' }, [{ error: e.message }.to_json]]
    end
  end
end
