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
      Net::HTTP.start("localhost", @pact_port) do |http|
        http.request(http_request)
      end
    rescue StandardError => e
      LOGGER.error("Error sending Pact interaction: #{e.message}")
      raise
    end
  end

  class Middleware
    def initialize(app, options = {})
      @app = app
      @discovery_strategy = options[:discovery_strategy] || :convention
      @service_mappings = {}
    end
  
    def register_service(service_class, controller_class)
      @service_mappings[service_class.name] = controller_class
    end
  
    def call(env)
      request = Rack::Request.new(env)
      path_parts = request.path_info.split("/")
      
      return @app.call(env) if path_parts[1] != "pact"
  
      grpc_module = path_parts[2].gsub('_', '::')
      method_name = path_parts[3].to_sym
  
      request_class = "#{grpc_module}::#{request.params['request']}".constantize
      service_class = "#{grpc_module}::#{request.params['service']}".constantize
      
      proto_request = request_class.decode_json(request.body.read)
      
      controller = find_controller_for_service(service_class).new(
        service: service_class,
        method_key: method_name,
        rpc_desc: service_class::Service.rpc_descs[method_name],
        active_call: nil,
        message: proto_request
      )
      response = controller.send(method_name)
  
      [200, { "Content-Type" => "application/json" }, [response.to_json]]
    rescue StandardError => e
      [500, { "Content-Type" => "application/json" }, [{ error: e.message }.to_json]]
    end
  
    private
  
    def find_controller_for_service(service_class)
      case @discovery_strategy
      when :convention
        find_by_convention(service_class)
      when :config
        find_by_config(service_class)
      when :reflection
        find_by_reflection(service_class)
      end
    end
  
    def find_by_convention(service_class)
      service_name = service_class.name.split('::').last
      base_name = service_name.sub(/Service$/, '')
      "#{base_name}Controller".constantize
    end
  
    def find_by_config(service_class)
      @service_mappings[service_class.name] || raise("No controller registered for service: #{service_class.name}")
    end
  
    def find_by_reflection(service_class)
      ObjectSpace.each_object(Class).find do |klass|
        klass.instance_methods.include?(service_class.instance_methods.first)
      end
    end
  end
end
