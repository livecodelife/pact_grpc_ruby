require 'grpc'

module Example
  class ExampleRequest < ::GRPC::GenericStruct
    attr_accessor :name

    def initialize(name: '')
      @name = name
    end
  end

  class ExampleResponse < ::GRPC::GenericStruct
    attr_accessor :message

    def initialize(message: '')
      @message = message
    end
  end

  class ExampleService < Example::ExampleService::Service
    def example_method(request, _call)
      Logger.new($stdout).info("Received request: #{request.inspect}")
      ExampleResponse.new(message: "Hello, #{request.name}!")
    rescue StandardError => e
      Logger.new($stderr).error("Error processing request: #{e.message}")
      raise GRPC::BadStatus.new_status_exception(GRPC::Core::StatusCodes::INTERNAL, e.message)
    end
  end
end