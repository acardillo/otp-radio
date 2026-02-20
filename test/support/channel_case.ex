defmodule OtpRadioWeb.ChannelCase do
  @moduledoc """
  Test case template for Phoenix Channel tests.

  Provides Phoenix.ChannelTest helpers and endpoint for testing
  channels without a database (no sandbox).
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import OtpRadioWeb.ChannelCase

      @endpoint OtpRadioWeb.Endpoint
    end
  end

  setup _tags do
    :ok
  end
end
