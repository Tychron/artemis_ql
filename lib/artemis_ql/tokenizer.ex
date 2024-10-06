defmodule ArtemisQL.Tokenizer do
  import ArtemisQL.Tokens
  import ArtemisQL.Utils

  @type token_meta :: ArtemisQL.Tokens.token_meta()

  @type token :: ArtemisQL.Tokens.token()

  @type tokens :: ArtemisQL.Tokens.tokens()

  @type internal_token :: ArtemisQL.Tokens.internal_token()

  defmacrop next_col(meta, amount) do
    quote do
      %{
        col_no: col_no,
        line_no: line_no,
      } = unquote(meta)

      %{
        col_no: col_no + unquote(amount),
        line_no: line_no
      }
    end
  end

  defmacrop next_col(meta) do
    quote do
      next_col(unquote(meta), 1)
    end
  end

  defmacrop next_line(meta, amount) do
    quote do
      %{
        line_no: line_no
      } = unquote(meta)

      %{
        line_no: line_no + unquote(amount),
        col_no: 1
      }
    end
  end

  defmacrop next_line(meta) do
    quote do
      next_line(unquote(meta), 1)
    end
  end

  @doc """
  Converts the given blob into a list of tokens, this function may return the remaining string if
  not everything could be parsed, it is expected that callers check the 'rest' string to ensure
  all tokens have been parsed.

  The second argument is not intended to be used by the caller, instead it is used to implement
  the recursive parsing of the blob.

  Example:

      {:ok, _tokens, meta, ""} = tokenize_all(blob)

  """
  @spec tokenize_all(String.t(), acc::tokens(), token_meta()) ::
    {:ok, tokens(), token_meta(), rest::String.t()}
    | {:error, term()}
  def tokenize_all(
    rest,
    acc \\ [],
    meta \\ %{line_no: 1, col_no: 1}
  ) when is_binary(rest) and is_list(acc) and is_map(meta) do
    case tokenize(rest, nil, meta) do
      {:ok, {:eos, _, _}, meta, rest} ->
        {:ok, Enum.reverse(acc), meta, rest}

      {:ok, token, meta, rest} ->
        tokenize_all(rest, [token | acc], meta)

      {:error, _} = err ->
        err
    end
  end

  @spec tokenize(String.t(), state::any()) ::
    {:ok, internal_token(), token_meta(), rest::String.t()}
    | {:error, term()}
  def tokenize(rest, state \\ nil, meta \\ %{line_no: 1, col_no: 1})

  #
  # End of String, or End of Sequence
  #

  def tokenize(<<>>, nil, meta) do
    {:ok, {:eos, nil, meta}, meta, ""}
  end

  #
  # Newlines & Spaces
  #

  def tokenize(
    <<c::utf8, _rest::binary>> = rest,
    nil,
    meta
  ) when is_utf8_newline_like_char(c) or is_utf8_space_like_char(c) do
    {spaces, rest_meta, rest} = trim_leading_spaces_and_newlines(rest, meta)
    {:ok, r_space_token(value: spaces, meta: meta), rest_meta, rest}
  end

  #
  # Quoted Strings
  #

  def tokenize(<<"\"", rest::binary>>, nil, meta) do
    tokenize(rest, {:quote, [], meta}, next_col(meta))
  end

  def tokenize("", {:quote, _acc, _qmeta} = token, meta) do
    {:error, {:unterminated_quote, token, meta}}
  end

  #
  # Quoted String - Closing quote
  #
  def tokenize(<<"\"", rest::binary>>, {:quote, acc, qmeta}, meta) do
    str = IO.iodata_to_binary(Enum.reverse(acc))
    {:ok, r_quote_token(value: str, meta: qmeta), next_col(meta), rest}
  end

  #
  # Quoted String - Escaped forms
  #
  def tokenize(<<"\\u{", rest::binary>>, {:quote, acc, qmeta}, meta) do
    meta = next_col(meta, 3)
    case tokenize(rest, {:unicode, [], meta}, meta) do
      {:ok, {:unicode, unicode, _umeta}, meta, <<"}", rest::binary>>} ->
        c = String.to_integer(unicode, 16)
        tokenize(rest, {:quote, [<<c::utf8>> | acc], qmeta}, next_col(meta, 1))

      {:error, _} = err ->
        err
    end
  end

  def tokenize(<<"\\u", unicode::binary-size(4), rest::binary>>, {:quote, acc, qmeta}, meta) do
    meta = next_col(meta, 6)
    c = String.to_integer(unicode, 16)
    tokenize(rest, {:quote, [<<c::utf8>> | acc], qmeta}, meta)
  end

  def tokenize(<<"\\", c::utf8, rest::binary>>, {:quote, acc, qmeta}, meta) do
    col = 1
    {col, acc} =
      case c do
        ?\\ -> {col + 1, ["\\" | acc]}
        ?" -> {col + 1, ["\"" | acc]}
        ?0 -> {col + 1, ["\0" | acc]}
        ?n -> {col + 1, ["\n" | acc]}
        ?f -> {col + 1, ["\f" | acc]}
        ?b -> {col + 1, ["\b" | acc]}
        ?r -> {col + 1, ["\r" | acc]}
        ?t -> {col + 1, ["\t" | acc]}
        ?v -> {col + 1, ["\v" | acc]}
        ?s -> {col + 1, ["\s" | acc]}
      end

    tokenize(rest, {:quote, acc, qmeta}, next_col(meta, col))
  end

  def tokenize(
    <<c1::utf8, c2::utf8, rest::binary>>,
    {:quote, acc, qmeta},
    meta
  ) when is_utf8_twochar_newline(c1, c2) do
    c = <<c1::utf8, c2::utf8>>
    tokenize(rest, {:quote, [c | acc], qmeta}, next_line(meta, 1))
  end

  def tokenize(
    <<c::utf8, rest::binary>>,
    {:quote, acc, qmeta},
    meta
  ) when is_utf8_newline_like_char(c) do
    tokenize(rest, {:quote, [<<c::utf8>> | acc], qmeta}, next_line(meta, 1))
  end

  def tokenize(
    <<c::utf8, rest::binary>>,
    {:quote, acc, qmeta},
    meta
  ) when is_utf8_space_like_char(c) do
    tokenize(rest, {:quote, [<<c::utf8>> | acc], qmeta}, next_col(meta, utf8_char_byte_size(c)))
  end

  def tokenize(
    <<c::utf8, rest::binary>>,
    {:quote, acc, qmeta},
    meta
  ) when c > 0x20 and is_utf8_scalar_char(c) do
    tokenize(rest, {:quote, [<<c::utf8>> | acc], qmeta}, next_col(meta, utf8_char_byte_size(c)))
  end

  #
  # Quoted String - Unicode sequence
  #
  def tokenize(
    <<c::utf8, rest::binary>>,
    {:unicode, acc, umeta},
    meta
  ) when is_utf8_hex_char(c) do
    tokenize(rest, {:unicode, [<<c::utf8>> | acc], umeta}, next_col(meta, 1))
  end

  def tokenize(
    <<"}", _rest::binary>> = rest,
    {:unicode, acc, umeta},
    meta
  ) do
    {:ok, {:unicode, IO.iodata_to_binary(Enum.reverse(acc)), umeta}, meta, rest}
  end

  def tokenize(
    _rest,
    {:unicode, _acc, _umeta} = token,
    meta
  ) do
    {:error, {:invalid_unicode_sequence, token, meta}}
  end

  #
  # Special Markers
  #
  def tokenize(<<"^", rest::binary>>, nil, meta) do
    {:ok, r_pin_token(meta: meta), next_col(meta), rest}
  end

  #
  # Operators
  #

  def tokenize(<<">=", rest::binary>>, nil, meta) do
    {:ok, r_cmp_op_token(value: :gte, meta: meta), next_col(meta, 2), rest}
  end

  def tokenize(<<"<=", rest::binary>>, nil, meta) do
    {:ok, r_cmp_op_token(value: :lte, meta: meta), next_col(meta, 2), rest}
  end

  def tokenize(<<"!~", rest::binary>>, nil, meta) do
    {:ok, r_cmp_op_token(value: :nfuzz, meta: meta), next_col(meta, 2), rest}
  end

  def tokenize(<<">", rest::binary>>, nil, meta) do
    {:ok, r_cmp_op_token(value: :gt, meta: meta), next_col(meta), rest}
  end

  def tokenize(<<"<", rest::binary>>, nil, meta) do
    {:ok, r_cmp_op_token(value: :lt, meta: meta), next_col(meta), rest}
  end

  def tokenize(<<"!", rest::binary>>, nil, meta) do
    {:ok, r_cmp_op_token(value: :neq, meta: meta), next_col(meta), rest}
  end

  def tokenize(<<"=", rest::binary>>, nil, meta) do
    {:ok, r_cmp_op_token(value: :eq, meta: meta), next_col(meta), rest}
  end

  def tokenize(<<"~", rest::binary>>, nil, meta) do
    {:ok, r_cmp_op_token(value: :fuzz, meta: meta), next_col(meta), rest}
  end

  #
  # Group
  #

  def tokenize(<<"(", rest::binary>>, nil, meta) do
    case tokenize_all(rest, [], next_col(meta)) do
      {:ok, contents, new_meta, <<")", rest :: binary>>} ->
        {:ok, {:group, contents, meta}, next_col(new_meta), rest}

      {:ok, contents, new_meta, rest} ->
        {:error, {:unterminated_group, contents, new_meta, rest}}

      {:error, reason} ->
        {:error, {:invalid_group, reason, rest, meta}}
    end
  end

  #
  # Wildcards
  #

  def tokenize(<<"*", rest::binary>>, nil, meta) do
    {:ok, r_wildcard_token(meta: meta), next_col(meta), rest}
  end

  def tokenize(<<"?", rest::binary>>, nil, meta) do
    {:ok, r_any_char_token(meta: meta), next_col(meta), rest}
  end

  #
  # Misc
  #

  def tokenize(<<":", rest::binary>>, nil, meta) do
    {:ok, {:pair_op, nil, meta}, next_col(meta), rest}
  end

  def tokenize(<<"..", rest::binary>>, nil, meta) do
    {:ok, {:range_op, nil, meta}, next_col(meta, 2), rest}
  end

  def tokenize(<<",", rest::binary>>, nil, meta) do
    {:ok, {:continuation_op, nil, meta}, next_col(meta), rest}
  end

  #
  # Everything else is just a word
  #

  def tokenize(<<rest::binary>>, nil, meta) do
    case tokenize_word(rest) do
      {:ok, "", rest} ->
        {:ok, {:eos, nil, meta}, meta, rest}

      {:ok, word, rest} ->
        {:ok, {:word, word, meta}, next_col(meta, byte_size(word)), rest}

      :error ->
        {:ok, {:eos, nil, meta}, meta, rest}
    end
  end

  defp tokenize_word(rest) when is_binary(rest) do
    do_tokenize_word(rest, [])
  end

  defp do_tokenize_word(<<>>, acc) do
    {:ok, IO.iodata_to_binary(acc), ""}
  end

  defp do_tokenize_word(
    <<"..", _rest::binary>> = rest,
    acc
  ) do
    {:ok, IO.iodata_to_binary(acc), rest}
  end

  defp do_tokenize_word(
    <<c::utf8, rest::binary>>,
    acc
  ) when c in [?@, ?-, ?_, ?.] or
        (c >= ?A and c <= ?Z) or
        (c >= ?a and c <= ?z) or
        (c >= ?0 and c <= ?9) or
        (c >= 0x00C0 and c < 0x00D7) or
        (c >= 0x00D8 and c < 0x00F7) or
        (c >= 0x00F8 and c < 0x0100) or
        (c >= 0x0180 and c < 0x01C0) or
        (c >= 0x01C4 and c < 0x02B9) or
        (c >= 0x0370 and c < 0x0374) or
        (c >= 0x0376 and c < 0x0378) or
        (c >= 0x037B and c < 0x037E) or
        c == 0x037F or c == 0x0386 or
        (c >= 0x0388 and c < 0x0483) or
        (c >= 0x048A and c < 0x0530) or
        (c >= 0x0531 and c < 0xD7FF) or
        (c >= 0xE000 and c <= 0x10FFFF)
  do
    do_tokenize_word(rest, [acc | <<c::utf8>>])
  end

  defp do_tokenize_word(
    rest,
    acc
  ) do
    {:ok, IO.iodata_to_binary(acc), rest}
  end

  defp trim_leading_spaces_and_newlines(rest, meta, acc \\ [])

  defp trim_leading_spaces_and_newlines(
    <<c::utf8, rest::binary>>,
    meta,
    acc
  ) when is_utf8_space_like_char(c) do
    trim_leading_spaces_and_newlines(
      rest,
      next_col(meta, utf8_char_byte_size(c)),
      [<<c::utf8>> | acc]
    )
  end

  defp trim_leading_spaces_and_newlines(
    <<c1::utf8, c2::utf8, rest::binary>>,
    meta,
    acc
  ) when is_utf8_twochar_newline(c1, c2) do
    trim_leading_spaces_and_newlines(
      rest,
      next_line(meta),
      [<<c1::utf8, c2::utf8>> | acc]
    )
  end

  defp trim_leading_spaces_and_newlines(
    <<c::utf8, rest::binary>>,
    meta,
    acc
  ) when is_utf8_newline_like_char(c) do
    trim_leading_spaces_and_newlines(
      rest,
      next_line(meta),
      [<<c::utf8>> | acc]
    )
  end

  defp trim_leading_spaces_and_newlines(rest, meta, acc) do
    {IO.iodata_to_binary(Enum.reverse(acc)), meta, rest}
  end
end
