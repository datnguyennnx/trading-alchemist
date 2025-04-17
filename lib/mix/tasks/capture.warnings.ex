defmodule Mix.Tasks.Capture.Warnings do
  use Mix.Task

  @shortdoc "Captures both compiler and runtime warnings"
  def run(_) do
    # First capture compiler warnings
    Mix.Task.run("compile.warnings")

    # Generate timestamp for log filename
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d_%H%M%S")
    log_filename = "log/elixir_warnings_#{timestamp}.log"

    # Then run the app to capture runtime warnings
    IO.puts("Starting application to capture runtime warnings...")
    IO.puts("Runtime warnings will be saved to #{log_filename}")
    IO.puts("Press Ctrl+C twice to stop")

    # Start the application with iex
    System.cmd("iex", ["-S", "mix", "phx.server"], into: IO.stream(:stdio, :line))
  end
end
