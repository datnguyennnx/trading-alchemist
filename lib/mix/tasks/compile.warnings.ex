defmodule Mix.Tasks.Compile.Warnings do
  use Mix.Task

  @shortdoc "Compiles and captures all compiler warnings to a file"
  @moduledoc """
  Compiles the project and captures all compiler warnings to a log file.

  The warnings are saved with timestamps in the log directory.

  ## Examples

      mix compile.warnings

  """

  def run(args) do
    # Create log directory if it doesn't exist
    File.mkdir_p!("log")

    # Generate timestamp for filename
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d_%H%M%S")
    log_filename = "log/compiler_warnings_#{timestamp}.log"

    # Check if verbose flag is set
    verbose? = Enum.member?(args, "--verbose") || Enum.member?(args, "-v")

    # Redirect stderr to capture compiler warnings
    {output, exit_code} = System.cmd("mix", ["compile", "--warnings-as-errors"],
      stderr_to_stdout: true,
      into: ""
    )

    # Extract warnings including file paths, line numbers, and messages
    warnings = extract_warnings(output)

    # Add timestamp to warnings and format them
    formatted_warnings = format_warnings(warnings)

    # Group warnings by file
    warnings_by_file = group_warnings_by_file(warnings)

    if Enum.empty?(formatted_warnings) do
      IO.puts("No compiler warnings found")
    else
      # Write warnings to file
      File.write!(log_filename, Enum.join(formatted_warnings, "\n") <> "\n")

      # Print summary
      print_summary(warnings_by_file, log_filename, verbose?)
    end

    # Recompile without --warnings-as-errors to allow compilation to complete
    if exit_code != 0 do
      Mix.Task.run("compile")
    end
  end

  defp extract_warnings(output) do
    # Regex to match warning patterns
    warning_regex = ~r/warning:.+|\.ex(?:s)?:\d+/

    # Get all lines containing warnings
    String.split(output, "\n")
    |> Enum.filter(&(Regex.match?(warning_regex, &1)))
    |> Enum.chunk_while(
      [],
      fn line, acc ->
        if String.contains?(line, "warning:") do
          {:cont, [line | acc], [line]}
        else
          {:cont, [line | acc]}
        end
      end,
      fn acc -> {:cont, acc, []} end
    )
    |> Enum.map(&Enum.reverse/1)
  end

  defp format_warnings(warnings) do
    current_time = DateTime.utc_now() |> DateTime.to_string()

    Enum.map(warnings, fn warning_lines ->
      formatted = Enum.join(warning_lines, "\n")
      "#{current_time} [warning]\n#{formatted}\n"
    end)
  end

  defp group_warnings_by_file(warnings) do
    Enum.reduce(warnings, %{}, fn warning_lines, acc ->
      file_path = extract_file_path(warning_lines)

      Map.update(acc, file_path, 1, &(&1 + 1))
    end)
  end

  defp extract_file_path(warning_lines) do
    Enum.find_value(warning_lines, "unknown_file", fn line ->
      case Regex.run(~r/([a-zA-Z0-9_\/.]+\.exs?:\d+)/, line) do
        [_, file_path] -> file_path
        _ -> nil
      end
    end)
  end

  defp print_summary(warnings_by_file, log_filename, verbose?) do
    total_warnings = Enum.sum(Map.values(warnings_by_file))

    IO.puts("#{total_warnings} compiler warning(s) captured to #{log_filename}")

    if verbose? do
      IO.puts("\nWarnings by file:")

      warnings_by_file
      |> Enum.sort_by(fn {_, count} -> count end, :desc)
      |> Enum.each(fn {file, count} ->
        IO.puts("  #{file}: #{count} warning(s)")
      end)
    end
  end
end
