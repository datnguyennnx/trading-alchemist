# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :central,
  ecto_repos: [Central.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :central, CentralWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: CentralWeb.Template.ErrorHTML, json: CentralWeb.Template.ErrorJSON],
    layout: false
  ],
  pubsub_server: Central.PubSub,
  live_view: [signing_salt: "IfEg7X40"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :central, Central.Mailer, adapter: Swoosh.Adapters.Local

config :esbuild,
  version: "0.25.3",
  central: [
    args: ~w(js/app.js --bundle --target=es2020 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "4.0.9",
  central: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger,
  backends: [:console, {LoggerFileBackend, :warning_log}],
  level: :info,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

config :logger, :console,
  format: "[$date $time] $metadata[$level] $message\n",
  metadata: [:request_id],
  colors: [enabled: true],
  time_format: "%H:%M:%S",
  date_format: "%d/%m/%Y"

timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d_%H%M%S")
config :logger, :warning_log,
  path: "log/elixir_warnings_#{timestamp}.log",
  level: :warning,
  format: "$date $time [$level] $message\n"

# Configure Tesla HTTP client
config :tesla, adapter: {Tesla.Adapter.Finch, [name: Central.Finch, pool_timeout: 5000]}

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
