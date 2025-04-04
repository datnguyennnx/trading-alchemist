defmodule Central.Config.HTTP do
  @moduledoc """
  Provides consistent HTTP status handling and utilities across the application.
  """

  # Define status code ranges as module attributes for use in guard clauses
  @success_status_range 200..299
  @client_error_range 400..499
  @server_error_range 500..599

  @doc """
  The range of HTTP status codes that indicate a successful response.
  """
  def success_status_range, do: @success_status_range

  @doc """
  The range of HTTP status codes that indicate a client error.
  """
  def client_error_range, do: @client_error_range

  @doc """
  The range of HTTP status codes that indicate a server error.
  """
  def server_error_range, do: @server_error_range

  @doc """
  Checks if the given status code indicates a successful response.

  ## Examples

      iex> Central.Config.HTTP.success?(200)
      true

      iex> Central.Config.HTTP.success?(404)
      false
  """
  def success?(status) when is_integer(status), do: status in @success_status_range

  @doc """
  Checks if the given status code indicates a client error.

  ## Examples

      iex> Central.Config.HTTP.client_error?(400)
      true

      iex> Central.Config.HTTP.client_error?(200)
      false
  """
  def client_error?(status) when is_integer(status), do: status in @client_error_range

  @doc """
  Checks if the given status code indicates a server error.

  ## Examples

      iex> Central.Config.HTTP.server_error?(500)
      true

      iex> Central.Config.HTTP.server_error?(200)
      false
  """
  def server_error?(status) when is_integer(status), do: status in @server_error_range

  @doc """
  Returns a descriptive message for HTTP error status codes.

  ## Examples

      iex> Central.Config.HTTP.status_message(404)
      "Not Found"

      iex> Central.Config.HTTP.status_message(500)
      "Internal Server Error"
  """
  def status_message(status) do
    case status do
      400 -> "Bad Request"
      401 -> "Unauthorized"
      403 -> "Forbidden"
      404 -> "Not Found"
      405 -> "Method Not Allowed"
      408 -> "Request Timeout"
      409 -> "Conflict"
      429 -> "Too Many Requests"
      500 -> "Internal Server Error"
      502 -> "Bad Gateway"
      503 -> "Service Unavailable"
      504 -> "Gateway Timeout"
      _ when status in @client_error_range -> "Client Error"
      _ when status in @server_error_range -> "Server Error"
      _ -> "Unknown Status"
    end
  end

  @doc """
  Formats an error response with a consistent structure.

  ## Examples

      iex> Central.Config.HTTP.format_error(404, "User not found")
      %{status: 404, message: "Not Found", details: "User not found"}
  """
  def format_error(status, details \\ nil) do
    %{
      status: status,
      message: status_message(status),
      details: details
    }
  end

  @doc """
  Extracts an error message from a response body, handling different formats.

  ## Examples

      iex> Central.Config.HTTP.extract_error_message(%{"msg" => "Invalid parameter"})
      "Invalid parameter"

      iex> Central.Config.HTTP.extract_error_message(%{"message" => "Rate limited"})
      "Rate limited"

      iex> Central.Config.HTTP.extract_error_message("Plain error message")
      "Plain error message"
  """
  def extract_error_message(body) when is_map(body) do
    cond do
      Map.has_key?(body, "msg") && is_binary(body["msg"]) -> body["msg"]
      Map.has_key?(body, "message") && is_binary(body["message"]) -> body["message"]
      Map.has_key?(body, "error") && is_binary(body["error"]) -> body["error"]
      true -> inspect(body)
    end
  end
  def extract_error_message(body) when is_binary(body), do: body
  def extract_error_message(body), do: inspect(body)
end
