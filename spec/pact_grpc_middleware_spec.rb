require 'rspec'
require 'rack'
require 'pact_grpc_ruby' # Adjust the require path as necessary

RSpec.describe PactGrpcRuby::PactGrpcMiddleware do
  let(:grpc_service_stub) { double('GrpcServiceStub') }
  let(:middleware) { described_class.new(grpc_service_stub) }
  let(:env) { { 'PATH_INFO' => '/example_method', 'rack.input' => StringIO.new('{"key":"value"}') } }
  let(:proto_class) { double('ProtoClass') }
  let(:proto_request) { double('ProtoRequest') }
  let(:response) { double('Response', to_json: '{"response_key":"response_value"}') }

  before do
    allow(Object).to receive(:const_get).with('example_method').and_return(proto_class)
    allow(proto_class).to receive(:decode_json).and_return(proto_request)
    allow(grpc_service_stub).to receive(:new).with('example_method', :this_channel).and_return(grpc_service_stub)
    allow(grpc_service_stub).to receive(:call).with(proto_request).and_return(response)
  end

  it 'processes a valid request and returns a JSON response' do
    status, headers, body = middleware.call(env)
    expect(status).to eq(200)
    expect(headers['Content-Type']).to eq('application/json')
    expect(body).to eq(['{"response_key":"response_value"}'])
  end

  it 'handles errors and returns a 500 response' do
    allow(proto_class).to receive(:decode_json).and_raise(StandardError.new("Decode error"))
    status, headers, body = middleware.call(env)
    expect(status).to eq(500)
    expect(headers['Content-Type']).to eq('application/json')
    expect(body).to eq([{ error: "Decode error" }.to_json])
  end
end