defmodule Central.Logger do
  @moduledoc """
  Centralized logging utility that provides structured logging
  with additional context and filtering capabilities.
  """

  require Elixir.Logger

  @doc """
  Logs a message at the debug level with additional context.
  """
  def debug(message, metadata \\ []) do
    log(:debug, message, metadata)
  end

  @doc """
  Logs a message at the info level with additional context.
  """
  def info(message, metadata \\ []) do
    log(:info, message, metadata)
  end

  @doc """
  Logs a message at the warning level with additional context.
  """
  def warn(message, metadata \\ []) do
    log(:warn, message, metadata)
  end

  @doc """
  Logs a message at the error level with additional context.
  """
  def error(message, metadata \\ []) do
    log(:error, message, metadata)
  end

  @doc """
  Logs an exception with full stack trace and context at the error level.
  """
  def exception(exception, stacktrace \\ nil, metadata \\ []) do
    stacktrace = stacktrace || Process.info(self(), :current_stacktrace) |> elem(1)

    metadata =
      metadata
      |> Keyword.put(:exception, Exception.message(exception))
      |> Keyword.put(:stacktrace, format_stacktrace(stacktrace))

    error("Exception: #{Exception.message(exception)}", metadata)
  end

  @doc """
  Logs details about an external API request.
  """
  def api_request(method, url, status, duration, metadata \\ []) do
    metadata =
      metadata
      |> Keyword.put(:method, method)
      |> Keyword.put(:url, url)
      |> Keyword.put(:status, status)
      |> Keyword.put(:duration_ms, duration)

    level = determine_api_log_level(status)
    message = "API #{method} #{url} - Status: #{status} (#{duration}ms)"

    log(level, message, metadata)
  end

  @doc """
  Logs metrics and performance data for analysis.
  """
  def metric(name, value, unit \\ nil, metadata \\ []) do
    metadata =
      metadata
      |> Keyword.put(:metric_name, name)
      |> Keyword.put(:metric_value, value)
      |> Keyword.put_new(:metric_unit, unit)

    info("Metric #{name}: #{value}#{unit_string(unit)}", metadata)
  end

  # Private helper functions

  defp log(level, message, metadata) do
    # Add common metadata to all logs
    metadata =
      metadata
      |> Keyword.put_new(:module, get_calling_module())
      |> Keyword.put_new(:function, get_calling_function())
      |> Keyword.put_new(:timestamp, DateTime.utc_now())

    # Use Elixir's Logger with enhanced metadata
    apply(Elixir.Logger, level, [message, metadata])
  end

  defp determine_api_log_level(status) when is_integer(status) do
    cond do
      status >= 500 -> :error
      status >= 400 -> :warn
      true -> :info
    end
  end

  defp determine_api_log_level(_), do: :error

  defp unit_string(nil), do: ""
  defp unit_string(unit), do: " #{unit}"

  defp format_stacktrace(stacktrace) do
    stacktrace
    |> Exception.format_stacktrace()
    |> String.split("\n")
    |> Enum.join(" | ")
  end

  defp get_calling_module do
    self()
    |> Process.info(:current_stacktrace)
    |> elem(1)
    |> Enum.drop(3)
    |> List.first()
    |> case do
      {module, _, _, _} -> module
      _ -> nil
    end
  end

  defp get_calling_function do
    self()
    |> Process.info(:current_stacktrace)
    |> elem(1)
    |> Enum.drop(3)
    |> List.first()
    |> case do
      {_, function, arity, _} -> "#{function}/#{arity}"
      _ -> nil
    end
  end
end
