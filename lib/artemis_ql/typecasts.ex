defmodule ArtemisQL.Typecasts do
  alias ArtemisQL.Types.ValueTransformError

  import ArtemisQL.Utils

  @spec cast_binary_id(binary()) :: {:ok, String.t()} | :error
  def cast_binary_id(value) when is_binary(value) do
    case cast_uuid(value) do
      {:ok, _value} = result -> result
      :error -> cast_ulid(value)
    end
  end

  def cast_binary_id(_value), do: :error

  @spec cast_uuid(binary()) :: {:ok, String.t()} | :error
  def cast_uuid(str) do
    Ecto.UUID.cast(str)
  end

  @spec cast_ulid(binary()) :: {:ok, String.t()} | :error
  def cast_ulid(str) do
    Ecto.ULID.cast(str)
  end

  @spec cast_boolean(String.t()) :: {:ok, boolean()}
  def cast_boolean(value) when is_binary(value) do
    case String.downcase(value) do
      v when v in ~w[yes y 1 true t on] ->
        {:ok, true}

      v when v in ~w[no n 0 false f off] ->
        {:ok, false}

      _ ->
        :error
    end
  end

  @spec cast_integer(String.t()) :: {:ok, integer()} | :error
  def cast_integer(value) when is_integer(value) do
    {:ok, value}
  end

  def cast_integer(value) when is_binary(value) do
    {sign, value} =
      case value do
        <<"-", rest::binary>> -> {-1, rest}
        <<"+", rest::binary>> -> {1, rest}
        _ -> {1, value}
      end

    with {:ok, value} <- parse_integer(value) do
      {:ok, value * sign}
    else
      :error ->
        :error
    end
  end

  def cast_float(value) when is_float(value), do: {:ok, value}
  def cast_float(value) when is_integer(value), do: {:ok, value * 1.0}

  def cast_float(value) when is_binary(value) do
    with {:ok, value} <- normalize_decimal_string(value) do
      Ecto.Type.cast(:float, value)
    else
      :error ->
        :error
    end
  end

  def cast_decimal(%Decimal{} = value), do: {:ok, value}

  def cast_decimal(value) when is_integer(value) or is_float(value) do
    Ecto.Type.cast(:decimal, value)
  end

  def cast_decimal(value) when is_binary(value) do
    with {:ok, value} <- normalize_decimal_string(value) do
      Ecto.Type.cast(:decimal, value)
    else
      :error ->
        :error
    end
  end

  @spec cast_inet(String.t()) :: {:ok, String.t()} | :error
  def cast_inet(value) when is_binary(value) do
    with {:ok, _ip, _prefix} <- parse_network_value(value, false) do
      {:ok, value}
    else
      :error -> :error
    end
  end

  @spec cast_cidr(String.t()) :: {:ok, String.t()} | :error
  def cast_cidr(value) when is_binary(value) do
    with {:ok, _ip, _prefix} <- parse_network_value(value, true) do
      {:ok, value}
    else
      :error -> :error
    end
  end

  defp parse_network_value(value, require_prefix?) when is_binary(value) do
    case String.split(value, "/", parts: 2) do
      [ip] ->
        case require_prefix? do
          true ->
            :error

          false ->
            with {:ok, parsed} <- parse_ip(ip) do
              {:ok, parsed, nil}
            else
              :error -> :error
            end
        end

      [ip, prefix_str] ->
        with {:ok, parsed} <- parse_ip(ip),
             {:ok, prefix} <- parse_network_prefix(prefix_str, parsed) do
          {:ok, parsed, prefix}
        else
          :error -> :error
        end

      _ ->
        :error
    end
  end

  defp parse_ip(value) when is_binary(value) do
    case :inet.parse_address(String.to_charlist(value)) do
      {:ok, ip} -> {:ok, ip}
      {:error, _} -> :error
    end
  end

  defp parse_network_prefix(prefix_str, ip) when is_binary(prefix_str) do
    max_prefix =
      case tuple_size(ip) do
        4 -> 32
        8 -> 128
      end

    case Integer.parse(prefix_str, 10) do
      {prefix, ""} when prefix >= 0 and prefix <= max_prefix ->
        {:ok, prefix}

      _ ->
        :error
    end
  end

  @spec cast_atom(String.t()) :: {:ok, atom()} | :error
  def cast_atom(str) do
    {:ok, String.to_existing_atom(str)}
  rescue
    ArgumentError -> :error
  end

  @spec cast_date(String.t()) :: {:ok, Date.t()}
  def cast_date(value) do
    {:ok, ArtemisQL.Types.DateAndTime.parse_date(value)}
  rescue _ex in ValueTransformError ->
    :error
  end

  @spec cast_time(String.t()) :: {:ok, Time.t()}
  def cast_time(value) do
    {:ok, ArtemisQL.Types.DateAndTime.parse_time(value)}
  rescue _ex in ValueTransformError ->
    :error
  end

  @spec cast_datetime(String.t()) :: {:ok, Time.t()}
  def cast_datetime(value) do
    {:ok, ArtemisQL.Types.DateAndTime.parse_datetime(value)}
  rescue _ex in ValueTransformError ->
    :error
  end

  @spec cast_naive_datetime(String.t()) :: {:ok, Time.t()}
  def cast_naive_datetime(value) do
    {:ok, ArtemisQL.Types.DateAndTime.parse_naive_datetime(value)}
  rescue _ex in ValueTransformError ->
    :error
  end
end
