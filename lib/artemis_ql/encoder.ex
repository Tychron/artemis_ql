defmodule ArtemisQL.Encoder do
  @type search_list :: term()

  @type encode_option :: {:return, :iodata | :binary}

  @type encode_options :: [encode_option()]

  @spec encode(search_list(), encode_options()) :: {:ok, String.t()} | {:error, term}
  def encode(tokens, options \\ []) when is_list(tokens) do
    do_encode(tokens, [], options)
  end

  defp do_encode([], acc, options) do
    blob =
      acc
      |> Enum.reverse()
      |> Enum.intersperse(" ")

    case Keyword.get(options, :return, :binary) do
      :iodata ->
        {:ok, blob}

      :binary ->
        blob =
          blob
          |> IO.iodata_to_binary()

        {:ok, blob}
    end
  end

  defp do_encode([item | rest], acc, options) do
    do_encode(rest, [encode_term(item) | acc], options)
  end

  defp encode_term(:NULL) do
    "NULL"
  end

  defp encode_term({:range, {s, e}}) do
    s = encode_term(s)
    e = encode_term(e)

    [s, "..", e]
  end

  defp encode_term({:pair, {key, value}}) do
    key = encode_term(key)
    value = encode_term(value)
    [key, ":", value]
  end

  defp encode_term({:partial, segments}) when is_list(segments) do
    Enum.map(segments, fn
      :wildcard ->
        "*"

      :any_char ->
        "?"

      term ->
        encode_term(term)
    end)
  end

  defp encode_term({:word, key}) when is_binary(key) do
    key
  end

  defp encode_term({:cmp, {op, value}}) do
    prefix =
      case op do
        :gt -> ">"
        :gte -> ">="
        :lt -> "<"
        :lte -> "<="
        :eq -> "="
        :neq -> "!"
      end

    [prefix, encode_term(value)]
  end

  defp encode_term({:quote, value}) when is_binary(value) do
    encode_quoted_string(value)
  end

  defp encode_term({:group, list}) when is_list(list) do
    {:ok, blob} = encode(list, return: :iodata)
    ["(", blob, ")"]
  end

  defp encode_term({:list, list}) when is_list(list) do
    list
    |> Enum.map(fn item ->
      encode_term(item)
    end)
    |> Enum.intersperse(",")
  end

  defp encode_quoted_string(str) when is_binary(str) do
    ["\"", ArtemisQL.Util.escape_quoted_string(str), "\""]
  end
end
