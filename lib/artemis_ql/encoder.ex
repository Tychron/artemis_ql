defmodule ArtemisQL.Encoder do
  import ArtemisQL.Tokens

  @type search_list :: term()

  @type encode_option :: {:return, :iodata | :binary}

  @type encode_options :: [encode_option()]

  @spec encode(search_list(), encode_options()) :: {:ok, String.t()} | {:error, term}
  def encode(tokens, options \\ []) when is_list(tokens) do
    do_encode(tokens, [], options)
  end

  def encode_value(r_null_token()) do
    {:ok, :NULL}
  end

  def encode_value(r_partial_token(items: list)) do
    {:ok, Enum.map(list, fn
      r_wildcard_token() ->
        %{:"$wildcard" => true}

      r_any_char_token() ->
        %{:"$any_char" => true}

      r_value_token(value: str) when is_binary(str) ->
        str
    end)}
  end

  def encode_value(bool) when is_boolean(bool) do
    {:ok, to_string(bool)}
  end

  def encode_value(val) when is_number(val) do
    {:ok, to_string(val)}
  end

  def encode_value(%st{} = val) when st in [Time, Date, DateTime, NaiveDateTime] do
    {:ok, st.to_iso8601(val)}
  end

  def encode_value(%Decimal{} = dec) do
    {:ok, Decimal.to_string(dec, :normal)}
  end

  def encode_value({:partial_time, {hour}}) do
    {:ok, String.pad_leading(to_string(hour), 2, "0")}
  end

  def encode_value({:partial_time, {hour, minute}}) do
    {:ok, String.pad_leading(to_string(hour), 2, "0") <> ":" <>
          String.pad_leading(to_string(minute), 2, "0")}
  end

  def encode_value({:partial_date, {year}}) do
    {:ok, String.pad_leading(to_string(year), 4, "0")}
  end

  def encode_value({:partial_date, {year, month}}) do
    {:ok, String.pad_leading(to_string(year), 4, "0") <> "-" <>
          String.pad_leading(to_string(month), 2, "0")}
  end

  def encode_value({part, date, time}) when part in [:partial_datetime, :partial_naive_datetime] do
    {:ok, date} = encode_value(date)
    {:ok, time} = encode_value(time)

    {:ok, date <> "T" <> time}
  end

  def encode_value(val) when is_binary(val) do
    {:ok, val}
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

  defp encode_term(r_null_token()) do
    "NULL"
  end

  defp encode_term(r_wildcard_token()) do
    "*"
  end

  defp encode_term(r_any_char_token()) do
    "?"
  end

  defp encode_term(r_range_token(pair: {s, e})) do
    s =
      case s do
        r_infinity_token() ->
          ""

        {_, _, _s_meta} ->
          encode_term(s)
      end

    e =
      case e do
        r_infinity_token() ->
          ""

        {_, _, _e_meta} ->
          encode_term(e)
      end

    [s, "..", e]
  end

  defp encode_term(r_pair_token(pair: {key, value})) do
    key = encode_term(key)
    value = encode_term(value)
    [key, ":", value]
  end

  defp encode_term(r_partial_token(items: segments)) when is_list(segments) do
    Enum.map(segments, fn
      :wildcard ->
        "*"

      :any_char ->
        "?"

      term ->
        encode_term(term)
    end)
  end

  defp encode_term(r_word_token(value: value)) when is_binary(value) do
    value
  end

  defp encode_term(r_cmp_token(pair: {op, value})) do
    prefix =
      case op do
        :gt -> ">"
        :gte -> ">="
        :lt -> "<"
        :lte -> "<="
        :eq -> "="
        :neq -> "!"
        :fuzz -> "~"
        :nfuzz -> "!~"
      end

    [prefix, encode_term(value)]
  end

  defp encode_term(r_quote_token(value: value)) when is_binary(value) do
    encode_quoted_string(value)
  end

  defp encode_term(r_group_token(items: list)) when is_list(list) do
    {:ok, blob} = encode(list, return: :iodata)
    ["(", blob, ")"]
  end

  defp encode_term(r_list_token(items: list)) when is_list(list) do
    list
    |> Enum.map(fn item ->
      encode_term(item)
    end)
    |> Enum.intersperse(",")
  end

  defp encode_term(r_pin_token(value: r_token() = term)) do
    ["^", encode_term(term)]
  end

  defp encode_quoted_string(str) when is_binary(str) do
    ["\"", ArtemisQL.Util.escape_quoted_string(str), "\""]
  end
end
