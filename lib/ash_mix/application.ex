defmodule AshMix.Application do
  @moduledoc false

  use Application

  if Mix.env() in [:dev, :test] do
    @impl true
    def start(_type, _args) do
      children = [Example.Repo]
      opts = [strategy: :one_for_one, name: AshMix.Supervisor]
      Supervisor.start_link(children, opts)
    end
  else
    @impl true
    def start(_type, _args), do: :ignore
  end
end
