defmodule OtpRadioWeb.Router do
  use OtpRadioWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", OtpRadioWeb do
    pipe_through :api

    get "/stations", StationController, :index
  end
end
