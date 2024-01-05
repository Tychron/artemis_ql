defmodule ArtemisQL.Tokenizer do
  import ArtemisQL.Tokens
  import ArtemisQL.Utils

  @type token_meta :: %{
    line_no: integer(),
    col_no: integer(),
  }

  @typedoc """
  All comparison operators recognized by the tokenizer

  Operators:
  * `gte` - `>=`, greater than or equal to
  * `lte` - `<=`, less than or equal to
  * `gt` - `>`, greater than
  * `lt` - `<`, less than
  * `neq` - `!`, not equal to
  * `eq` - `=`, equal to
  * `nfuzz` - `!~`, not fuzzy equal
  * `fuzz` - `~`, fuzzy equal
  """
  @type comparison_operator :: :gte
                             | :lte
                             | :gt
                             | :lt
                             | :neq
                             | :eq
                             | :fuzz
                             | :nfuzz

  @typedoc """
  End-of-Stream token, used to mark the end of a search string
  """
  @type eos_token :: {:eos, nil, token_meta()}

  @typedoc """
  Used to represent 1 or more spaces, this includes normal whitespace, tabs, newlines and
  carriage returns.
  """
  @type space_token :: {:space, spaces::String.t(), token_meta()}

  @typedoc """
  A quoted string is any number of characters originally enclosed in double-quotes ('"')
  """
  @type quoted_string_token :: {:quote, String.t(), token_meta()}

  @typedoc """
  A comparison operator, normally used to add some additional conditional to the value.
  """
  @type comparison_operator_token :: {:cmp_op, comparison_operator(), token_meta()}

  @typedoc """
  The wildcard token is denoted by `*` and generally means match anything, if its used
  within a set of words or quotes then it acts as a positional matcher.
  """
  @type wildcard_token :: {:wildcard, nil, token_meta()}

  @typedoc """
  The any_char token is denoted by `?`, it will match any one character in a string.
  """
  @type any_char_token :: {:any_char, nil, token_meta()}

  @typedoc """
  The pair operator token is used to denote key:value pairs
  """
  @type pair_op_token :: {:pair_op, nil, token_meta()}

  @typedoc """
  The range operator token is used to denote range pairs (e.g. `1..2`, `1..`, `..2`)
  """
  @type range_op_token :: {:range_op, nil, token_meta()}

  @typedoc """
  The continuation operator is used to denote lists (e.g. `1,2,3,4`)
  """
  @type continuation_op_token :: {:continuation_op, nil, token_meta()}

  @typedoc """
  Pins are used to reference other fields in pair matching, this allows you to compare one field
  with the other.

  Usage:

    updated_at:>=^expires_at
  """
  @type pin_token :: {:pin, nil, token_meta()}

  @typedoc """
  A word is any unbroken text excluding some special characters (only `_` and `-` are allowed)
  """
  @type word_token :: {:word, String.t(), token_meta()}

  @typedoc """
  Exported tokens are those that will be returned from tokenize_all, this includes all tokens,
  except :eos, which is used to tell tokenize_all/2 that there are no more tokens to parse.
  """
  @type token :: space_token()
                        | quoted_string_token()
                        | comparison_operator_token()
                        | wildcard_token()
                        | any_char_token()
                        | pair_op_token()
                        | range_op_token()
                        | continuation_op_token()
                        | pin_token()
                        | word_token()

  @type tokens :: [token()]

  @typedoc """
  The 'internal' token is all tokens plus the eos token, it is strictly used for
  bare bones tokenize
  """
  @type internal_token :: eos_token() | token()

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

  @spec tokenize(String.t(), state::any()) :: {:ok, internal_token(), token_meta(), rest::String.t()}
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
    {spaces, rest_meta, rest} = trim_spaces(rest, meta)
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
    tokenize(rest, {:quote, [c | acc], qmeta}, next_line(meta, byte_size(c)))
  end

  def tokenize(
    <<c::utf8, rest::binary>>,
    {:quote, acc, qmeta},
    meta
  ) when is_utf8_newline_like_char(c) do
    tokenize(rest, {:quote, [<<c::utf8>> | acc], qmeta}, next_line(meta, byte_size(<<c::utf8>>)))
  end

  def tokenize(
    <<c::utf8, rest::binary>>,
    {:quote, acc, qmeta},
    meta
  ) when is_utf8_space_like_char(c) do
    tokenize(rest, {:quote, [<<c::utf8>> | acc], qmeta}, next_col(meta, byte_size(<<c::utf8>>)))
  end

  def tokenize(
    <<c::utf8, rest::binary>>,
    {:quote, acc, qmeta},
    meta
  ) when c > 0x20 and is_utf8_scalar_char(c) do
    tokenize(rest, {:quote, [<<c::utf8>> | acc], qmeta}, next_col(meta, byte_size(<<c::utf8>>)))
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
    case String.split(rest, ~r/\A([@\w_\-]+)/, include_captures: true, parts: 2) do
      ["", word, rest] ->
        {:ok, {:word, word, meta}, next_col(meta, byte_size(word)), rest}

      [rest] ->
        {:ok, {:eos, nil, meta}, meta, rest}
    end
  end

  defp trim_spaces(rest, meta, acc \\ [])

  defp trim_spaces(<<c::utf8, rest::binary>>, meta, acc) when is_utf8_space_like_char(c) do
    trim_spaces(rest, next_col(meta, byte_size(<<c::utf8>>)), [<<c::utf8>> | acc])
  end

  defp trim_spaces(
    <<c1::utf8, c2::utf8, rest::binary>>,
    meta,
    acc
  ) when is_utf8_twochar_newline(c1, c2) do
    trim_spaces(
      rest,
      next_line(meta),
      [<<c1::utf8, c2::utf8>> | acc]
    )
  end

  defp trim_spaces(<<c::utf8, rest::binary>>, meta, acc) when is_utf8_newline_like_char(c) do
    trim_spaces(rest, next_line(meta), [<<c::utf8>> | acc])
  end

  defp trim_spaces(rest, meta, acc) do
    {IO.iodata_to_binary(Enum.reverse(acc)), meta, rest}
  end
end
