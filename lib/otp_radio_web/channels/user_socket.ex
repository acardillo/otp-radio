defmodule OtpRadioWeb.UserSocket do
  @moduledoc """
  WebSocket connection handler for OTP-Radio.

  Defines channel routes and connection lifecycle.
  """

  use Phoenix.Socket

  # Channel routes
  channel "broadcaster:*", OtpRadioWeb.BroadcasterChannel
  channel "listener:*", OtpRadioWeb.ListenerChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    # Accept all connections for now (add auth later)
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
