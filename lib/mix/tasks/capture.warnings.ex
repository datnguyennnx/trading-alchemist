defmodule Mix.Tasks.Capture.Warnings do
  use Mix.Task

  @shortdoc "Captures both compiler and runtime warnings"
  def run(_) do
    # First capture compiler warnings
    Mix.Task.run("compile.warnings")

    # Then run the app to capture runtime warnings
    IO.puts("Starting application to capture runtime warnings...")
    IO.puts("Runtime warnings will be saved to log/elixir_warnings.log")
    IO.puts("Press Ctrl+C twice to stop")

    # Start the application with iex
    System.cmd("iex", ["-S", "mix", "phx.server"], into: IO.stream(:stdio, :line))
  end
end
