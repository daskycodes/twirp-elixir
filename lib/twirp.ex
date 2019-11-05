defmodule Twirp do
  @moduledoc """
  Twirp provides an elixir implementation of the [twirp rpc framework](https://github.com/twitchtv/twirp)
  developed by Twitch. The protocol defines semantics for routing and
  serialization of RPCs based on protobufs.

  ## Example

  The canonical Twirp example is a Haberdasher service. Here's the protobuf
  description for the service.

  ```protobuf
  syntax = "proto3";

  package example;

  // Haberdasher service makes hats for clients.
  service Haberdasher {
    // MakeHat produces a hat of mysterious, randomly-selected color!
    rpc MakeHat(Size) returns (Hat);
  }

  // Size of a Hat, in inches.
  message Size {
    int32 inches = 1; // must be > 0
  }

  // A Hat is a piece of headwear made by a Haberdasher.
  message Hat {
    int32 inches = 1;
    string color = 2; // anything but "invisible"
    string name = 3; // i.e. "bowler"
  }
  ```

  We'll assume for now that this proto file lives in `priv/protos/service.proto`

  ### Code generation

  We can now use `protoc` to generate the files we need. You can run this command
  from the root directory of your project.

      $ protoc --proto_path=./priv/protos --elixir_out=./lib/example --twirp_elixir_out=./lib/example ./priv/protos/service.proto

  After running this command there should be 2 files located in `lib/example`.

  The message definitions:

  ```elixir
  defmodule Example.Size do
    @moduledoc false
    use Protobuf, syntax: :proto3

    @type t :: %__MODULE__{
            inches: integer
          }

    defstruct [:inches]

    field :inches, 1, type: :int32
  end

  defmodule Example.Hat do
    @moduledoc false
    use Protobuf, syntax: :proto3

    @type t :: %__MODULE__{
            inches: integer,
            color: String.t(),
            name: String.t()
          }
    defstruct [:inches, :color, :name]

    field :inches, 1, type: :int32
    field :color, 2, type: :string
    field :name, 3, type: :string
  end
  ```

  The service and client definition:

  ```elixir
  defmodule Example.HaberdasherService do
    @moduledoc false
    use Twirp.Service

    package "example"
    service "Haberdasher"

    rpc :MakeHat, Example.Size, Example.Hat, :make_hat
  end

  defmodule Example.HaberdasherClient do
    @moduledoc false
    use Twirp.Client, service: Example.HaberdasherService
  end
  ```

  ### Implementing the server

  Now that we've generated the service definition we can implement a "handler"
  module that will implement each "method".

  ```elixir
  defmodule Example.HaberdasherHandler do
    @colors ~w|white black brown red blue|
    @names ["bowler", "baseball cap", "top hat", "derby"]

    def make_hat(_ctx, size) do
      if size <= 0 do
        Twirp.Error.invalid_argument("I can't make a hat that small!")
      else
        %Haberdasher.Hat{
          inches: size.inches,
          color: Enum.random(@colors),
          name: Enum.random(@names)
        }
      end
    end
  end
  ```

  Separating the service and handler like this may seem a little odd but there are
  good reasons to do this. The most important is that it allows the service to be
  autogenerated again in the future. The second reason is that it allows us to
  easily mock service implementations for testing.

  ### Running the server

  To serve traffic Twirp provides a Plug. We use this plug to attach our service
  definition with our handler.

  ```elixir
  defmodule Example.Router do
    use Plug.Router

    plug Twirp.Plug,
      service: Haberdasher.HatMakerService,
      handler: Haberdasher.HatMakerHandler
  end
  ```

  ```elixir
  defmodule Example.Application do
    use Application

    def start(_type, _args) do
      children = [
        Plug.Cowboy.child_spec(scheme: :http, plug: Example.Router, options: [port: 4040]),
      ]

      opts = [strategy: :one_for_one, name: Example.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end
  ```

  If you start your application your plug will now be available on port 4040.

  ### Using the client

  Client definitions are generated alongside the service definition. This allows
  you to generate clients for your services in other applications.  You can make
  RPC calls like so:

  ```elixir
  defmodule AnotherService.GetHats do
    alias Example.HaberdasherClient, as: Client
    alias Example.{Size, Hat}

    def make_a_hat(inches) do
      client = Client.client("http://localhost:4040", [])

      case Client.make_hat(client, Size.new(inches: inches)) do
        {:ok, %Hat{}=hat} ->
          hat

        {:error, %Twirp.Error{msg: msg}} ->
          Logger.error(msg)
      end
    end
  end
  ```

  Under the hood the client that Twirp generates is a Tesla client. This means that
  you can re-use all of the existing Tesla middleware.
  """
end
