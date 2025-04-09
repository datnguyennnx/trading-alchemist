defmodule Central.Config.DateTimeConfig do
  @moduledoc """
  Alias for Central.Config.DateTime to maintain backward compatibility.
  This module forwards all calls to Central.Config.DateTime.
  """

  # Forward the format function that's causing the error
  defdelegate format(datetime), to: Central.Config.DateTime

  # Forward other common functions as well for future compatibility
  defdelegate format_with_timezone(datetime), to: Central.Config.DateTime
  defdelegate truncate(datetime), to: Central.Config.DateTime
  defdelegate parse(datetime_string, format), to: Central.Config.DateTime
  defdelegate now(), to: Central.Config.DateTime
  defdelegate add(datetime, value, unit), to: Central.Config.DateTime
  defdelegate timezone(), to: Central.Config.DateTime
end
