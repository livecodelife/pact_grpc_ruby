# frozen_string_literal: true

require "rspec"
require "grpc"
require "net/http"
require "pact_grpc_ruby"

RSpec.describe PactGrpcRuby::PactGrpcInterceptor do
  let(:pact_port) { 1234 }
  let(:interceptor) { described_class.new(pact_port) }
  let(:request) { double("Request", to_json: '{"key":"value"}') }
  let(:call) { double("Call") }
  let(:method) { "example_method" }
  let(:metadata) { {} }

  before do
    allow(Net::HTTP).to receive(:start).and_yield(double("HTTP", request: double("Response", code: "200")))
    allow(PactGrpcRuby::LOGGER).to receive(:info)
  end

  it "sends a Pact interaction and yields" do
    expect do |b|
      interceptor.request_response(request: request, call: call, method: method, metadata: metadata, &b)
    end.to yield_control
  end

  it "logs the response code" do
    interceptor.request_response(request: request, call: call, method: method, metadata: metadata)
    expect(PactGrpcRuby::LOGGER).to have_received(:info).with("Pact interaction sent: 200")
  end

  it "handles errors when sending Pact interaction" do
    allow(Net::HTTP).to receive(:start).and_raise(StandardError.new("Network error"))
    expect do
      interceptor.request_response(request: request, call: call, method: method,
                                   metadata: metadata)
    end.to raise_error(StandardError)
  end
end
