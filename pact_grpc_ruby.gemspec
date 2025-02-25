# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "pact_grpc_ruby"
  spec.version       = "0.1.0"
  spec.authors       = ["Caleb Cowen"]
  spec.email         = ["calebcowen@gmail.com"]
  spec.summary       = "A Ruby gem for gRPC contract testing using Pact."
  spec.description   = "Pact gRPC Ruby is a Ruby gem that facilitates contract testing between Ruby-based gRPC services using Pact."
  spec.homepage      = "https://github.com/calebcowen/pact_grpc_ruby"
  spec.license       = "MIT"
  spec.files         = Dir["lib/**/*.rb"] + Dir["spec/**/*.rb"] + ["README.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  # Add runtime dependencies
  spec.add_dependency "google-protobuf"
  spec.add_dependency "grpc"
  spec.add_dependency "rack"

  # Add development dependencies
  spec.add_development_dependency "rspec"
end
