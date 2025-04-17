defmodule Mix.Tasks.Compile.Warnings do
  use Mix.Task

  @shortdoc "Compiles and captures all compiler warnings to a file"
  def run(_) do
    # Create log directory if it doesn't exist
    File.mkdir_p!("log")

    # Redirect stderr to capture compiler warnings
    {output, exit_code} = System.cmd("mix", ["compile", "--warnings-as-errors"],
      stderr_to_stdout: true,
      into: ""
    )

    # Extract and format the warnings
    warnings = String.split(output, "\n")
    |> Enum.filter(&(String.contains?(&1, "warning:") || String.contains?(&1, "\\|")))

    # Add timestamp to warnings
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    formatted_warnings = Enum.map(warnings, fn warning ->
      "#{timestamp} [warning] #{warning}"
    end)

    # Write warnings to file
    if length(formatted_warnings) > 0 do
      File.write!("log/compiler_warnings.log",
        Enum.join(formatted_warnings, "\n") <> "\n",
        [:append]
      )

      # Print report
      IO.puts("#{length(formatted_warnings)} compiler warnings captured to log/compiler_warnings.log")
    else
      IO.puts("No compiler warnings found")
    end

    # Recompile without --warnings-as-errors to allow compilation to complete
    if exit_code != 0 do
      Mix.Task.run("compile")
    end
  end
end
