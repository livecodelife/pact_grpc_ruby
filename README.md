# Pact gRPC Ruby

## Description

Pact gRPC Ruby is a Ruby gem that facilitates contract testing between Ruby-based gRPC services using Pact. It allows developers to create and verify contracts between services, ensuring reliable communication in microservices architectures.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pact_grpc_ruby'
```

And then run:

```bash
$ bundle install
```

Or install it yourself with:

```bash
$ gem install pact_grpc_ruby
```

## Usage

### Consumer Side

To use the interceptor in your gRPC client, you can add the interceptor to the client's channel:

```ruby
require 'pact_grpc_ruby'

class MyGrpcClient
  def initialize(pact_port)
    @stub = MyGrpcService::Stub.new(
      'localhost:50051',
      :this_channel_is_insecure,
      interceptors: [PactGrpcRuby::PactGrpcInterceptor.new(pact_port)]
    )
  end

  def make_request
    request = MyRequest.new(name: 'World')
    response = @stub.example_method(request)
    puts response.message
  end
end

```

### Provider Side

To set up the middleware in your gRPC server:

```ruby
require 'pact_grpc_ruby'

class MyApp
  def initialize
    @grpc_service_stub = MyGrpcService::Stub.new('localhost:50051', :this_channel_is_insecure)
    @middleware = PactGrpcRuby::PactGrpcMiddleware.new(@grpc_service_stub)
  end

  def call(env)
    @middleware.call(env)
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/pact_grpc_ruby. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/pact_grpc_ruby/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the PactGrpcRuby project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/pact_grpc_ruby/blob/main/CODE_OF_CONDUCT.md).
