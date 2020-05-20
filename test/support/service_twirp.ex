# Generated by the protobuf compile. DO NOT EDIT!

defmodule Twirp.Test.EchoService do
  @moduledoc false
  use Twirp.Service

  package "twirp.test"
  service "Echo"

  rpc :Echo, Twirp.Test.Req, Twirp.Test.Resp, :echo
  rpc :SlowEcho, Twirp.Test.Req, Twirp.Test.Resp, :slow_echo
end

defmodule Twirp.Test.EchoClient do
  @moduledoc false
  use Twirp.Client, service: Twirp.Test.EchoService
end
