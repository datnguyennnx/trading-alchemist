defmodule Mix.Tasks.Show.Warnings do
  use Mix.Task

  @shortdoc "Shows all captured warnings"
  def run(_) do
    # Find most recent warning files
    compiler_warnings_file = find_most_recent_file("log/compiler_warnings_*.log")
    runtime_warnings_file = find_most_recent_file("log/elixir_warnings_*.log")

    # Check and display compiler warnings
    compiler_warnings = if compiler_warnings_file do
      compiler_content = File.read!(compiler_warnings_file)
      compiler_count = compiler_content |> String.split("\n") |> Enum.count(&(&1 != ""))
      IO.puts("\n\e[33m===== COMPILER WARNINGS (#{compiler_count}) =====\e[0m")
      IO.puts("File: #{compiler_warnings_file}")
      IO.puts(compiler_content)
      compiler_count
    else
      IO.puts("\n\e[33m===== COMPILER WARNINGS (0) =====\e[0m")
      IO.puts("No compiler warnings captured yet.")
      0
    end

    # Check and display runtime warnings
    runtime_warnings = if runtime_warnings_file do
      runtime_content = File.read!(runtime_warnings_file)
      runtime_count = runtime_content |> String.split("\n") |> Enum.count(&(&1 != ""))
      IO.puts("\n\e[33m===== RUNTIME WARNINGS (#{runtime_count}) =====\e[0m")
      IO.puts("File: #{runtime_warnings_file}")
      IO.puts(runtime_content)
      runtime_count
    else
      IO.puts("\n\e[33m===== RUNTIME WARNINGS (0) =====\e[0m")
      IO.puts("No runtime warnings captured yet.")
      0
    end

    # Show summary
    total_warnings = compiler_warnings + runtime_warnings
    IO.puts("\n\e[1m===== SUMMARY =====\e[0m")
    IO.puts("Total warnings: #{total_warnings}")
    IO.puts("Compiler warnings: #{compiler_warnings}")
    IO.puts("Runtime warnings: #{runtime_warnings}")
  end

  # Find the most recently modified file matching the pattern
  defp find_most_recent_file(pattern) do
    case Path.wildcard(pattern) do
      [] -> nil
      files ->
        files
        |> Enum.map(fn file -> {file, File.stat!(file).mtime} end)
        |> Enum.sort_by(fn {_file, time} -> time end, {:desc, DateTime})
        |> List.first()
        |> elem(0)
    end
  end
end
