# frozen_string_literal: true

require "rack"
require "grpc"
require "net/http"
require "google/protobuf"
require "logger"
require "json"
require_relative "pact_grpc_ruby/version"

module PactGrpcRuby
  LOGGER = Logger.new($stdout)
  LOGGER.level = Logger::INFO

  def self.mock_client(service, url = "localhost:50051", pact_port = 1234)
    service::Stub.new(url, :this_channel_is_insecure, interceptors: [PactGrpcInterceptor.new(pact_port)])
  end

  class PactGrpcInterceptor < GRPC::ClientInterceptor
    def initialize(pact_port)
      @pact_port = pact_port
    end

    def request_response(request:, call:, method:, metadata:)
      # Convert the gRPC request to JSON
      json_request = request.to_h.to_json

      # Construct the HTTP request to send to Pact
      http_request = Net::HTTP::Post.new("/pact/#{method.split("/").last.gsub(/([a-z])([A-Z])/, '\1_\2').downcase}")
      http_request.body = json_request
      http_request["Accept"] = "application/json"
      http_request["Content-Type"] = "application/json"

      # Send the HTTP request to the Pact server using the dynamic port
      Net::HTTP.start("localhost", @pact_port) do |http|
        http.request(http_request)
      end

    rescue StandardError => e
      LOGGER.error("Error sending Pact interaction: #{e.message}")
      raise
    end
  end

  class PactGrpcMiddleware
    def initialize(app, _options = {})
      @app = app
    end
  
    def call(env)
      request = Rack::Request.new(env)
      path_parts = request.path_info.split("/")
      
      # Ensure the path matches the expected format
      if path_parts.length != 4 || path_parts[1] != "pact"
        return @app.call(env) # Pass control to the next middleware if the path doesn't match
      end
  
      grpc_service = path_parts[2] # Extract the gRPC service name
      grpc_action = path_parts[3]   # Extract the gRPC action name
  
      # Convert JSON to Proto
      proto_class = Object.const_get(grpc_service) # Get the service class dynamically
      proto_request = proto_class.decode_json(request.body.read) # Decode the JSON request
  
      # Invoke the gRPC call
      grpc_stub = "#{grpc_service}::Stub".constantize.new("localhost:50051", :this_channel_is_insecure) # Create the gRPC stub
      response = grpc_stub.send(grpc_action, proto_request) # Call the appropriate gRPC action
  
      # Serialize the gRPC response into JSON
      [200, { "Content-Type" => "application/json" }, [response.to_json]]
    rescue StandardError => e
      LOGGER.error("Error processing request for #{grpc_action}: #{e.message}")
      [500, { "Content-Type" => "application/json" }, [{ error: e.message }.to_json]]
    end
  end
end
