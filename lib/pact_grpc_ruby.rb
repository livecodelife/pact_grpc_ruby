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

    def create_pact_path(request, method)
      method_name = method.split('/').last # Get the action part
      service_parts = method.split('/')[1..-2].join('').split('.') # Join the service parts

      # Format the service name and action for the URL
      service_name = service_parts.pop
      module_name = service_parts.map(&:camelize).join('_')
      formatted_action_name = method_name.gsub(/([A-Z])/, '_\1').downcase.sub(/^_/, '')

      "/pact/#{module_name}/#{formatted_action_name}?service=#{service_name}&request=#{request.class.to_s.split('::').last}"
    end

    def request_response(request:, call:, method:, metadata:)
      # Convert the gRPC request to JSON
      json_request = request.to_json

      # Construct the HTTP request to send to Pact
      url = create_pact_path(request,method)
      http_request = Net::HTTP::Post.new(url)
      http_request.body = json_request
      http_request["Accept"] = "application/json"
      http_request["Content-Type"] = "application/json"

      # Send the HTTP request to the Pact server using the dynamic port
      response = Net::HTTP.start("localhost", @pact_port) do |http|
        http.request(http_request)
      end

      raise StandardError.new("Request to path #{url} failed with response code: #{response.code}") unless response.code == "200"
      response
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
      if path_parts[1] != "pact"
        return @app.call(env) # Pass control to the next middleware if the path doesn't match
      end
  
      grpc_module = path_parts[2].gsub('_', '::') # Extract the gRPC service name
      grpc_action = path_parts[3].to_sym # Extract the gRPC action name
  
      # Convert JSON to Proto
      proto_class = Object.const_get("#{grpc_module}::#{request.params["request"].to_s}") # Get the service class dynamically
      proto_request = proto_class.decode_json(request.body.read) # Decode the JSON request
  
      # Invoke the gRPC call
      grpc_stub = "#{grpc_module}::#{request.params["service"]}::Stub".constantize.new("localhost:50051", :this_channel_is_insecure) # Create the gRPC stub
      response = grpc_stub.send(grpc_action, proto_request) # Call the appropriate gRPC action
  
      # Serialize the gRPC response into JSON
      [200, { "Content-Type" => "application/json" }, [response.to_h.to_json]]
    rescue StandardError => e
      LOGGER.error("Error processing request for #{grpc_action}: #{e.message}")
      [500, { "Content-Type" => "application/json" }, [{ error: e.message }.to_json]]
    end
  end
end
