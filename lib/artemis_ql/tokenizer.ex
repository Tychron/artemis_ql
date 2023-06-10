defmodule ArtemisQL.Tokenizer do
  import ArtemisQL.Tokens

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

      {:ok, _tokens, ""} = tokenize_all(blob)

  """
  @spec tokenize_all(String.t(), acc::tokens(), token_meta()) ::
    {:ok, tokens(), token_meta(), rest::String.t()}
  def tokenize_all(
    blob,
    acc \\ [],
    meta \\ %{line_no: 1, col_no: 1}
  ) when is_binary(blob) and is_list(acc) and is_map(meta) do
    case tokenize(blob, nil, meta) do
      {:ok, {:eos, _, _}, meta, blob} ->
        {:ok, Enum.reverse(acc), meta, blob}

      {:ok, token, meta, blob} ->
        tokenize_all(blob, [token | acc], meta)
    end
  end

  @spec tokenize(String.t(), state::any()) :: {:ok, internal_token(), token_meta(), rest::String.t()}
  def tokenize(blob, state \\ nil, meta \\ %{line_no: 1, col_no: 1})

  #
  # End of String, or End of Sequence
  #

  def tokenize(<<>>, nil, meta) do
    {:ok, {:eos, nil, meta}, meta, ""}
  end

  #
  # Space
  #

  def tokenize(<<space::utf8, _rest::binary>> = blob, nil, meta) when space in [?\s, ?\t, ?\r, ?\n] do
    {spaces, rest_meta, rest} = trim_spaces(blob, meta)
    {:ok, r_space_token(value: spaces, meta: meta), rest_meta, rest}
  end

  #
  # Quoted Strings
  #

  def tokenize(<<"\"", blob::binary>>, nil, meta) do
    tokenize(blob, {:quote, [], meta}, next_col(meta))
  end

  def tokenize("", {:quote, _acc, _qmeta} = token, meta) do
    {:error, {:unterminated_quote, token, meta}}
  end

  #
  # Closing quote
  #
  def tokenize(<<"\"", blob::binary>>, {:quote, acc, qmeta}, meta) do
    str = IO.iodata_to_binary(Enum.reverse(acc))
    {:ok, r_quote_token(value: str, meta: qmeta), next_col(meta), blob}
  end

  #
  # Escaped forms
  #
  def tokenize(<<"\\", c :: utf8, blob::binary>>, {:quote, acc, qmeta}, meta) do
    col = 1
    {col, acc} =
      case c do
        ?\\ -> {col + 1, ["\\" | acc]}
        ?" -> {col + 1, ["\"" | acc]}
        ?0 -> {col + 1, ["\0" | acc]}
        ?n -> {col + 1, ["\n" | acc]}
        ?r -> {col + 1, ["\r" | acc]}
        ?t -> {col + 1, ["\t" | acc]}
        ?s -> {col + 1, ["\s" | acc]}
      end

    tokenize(blob, {:quote, acc, qmeta}, next_col(meta, col))
  end

  def tokenize(<<"\r\n", blob::binary>>, {:quote, acc, qmeta}, meta) do
    tokenize(blob, {:quote, ["\r\n" | acc], qmeta}, next_line(meta))
  end

  def tokenize(<<"\n", blob::binary>>, {:quote, acc, qmeta}, meta) do
    tokenize(blob, {:quote, ["\n" | acc], qmeta}, next_line(meta))
  end

  def tokenize(<<"\r", blob::binary>>, {:quote, acc, qmeta}, meta) do
    tokenize(blob, {:quote, ["\r" | acc], qmeta}, next_line(meta))
  end

  def tokenize(<<c::utf8, blob::binary>>, {:quote, acc, qmeta}, meta) do
    tokenize(blob, {:quote, [<<c::utf8>> | acc], qmeta}, next_col(meta))
  end

  #
  # Special Markers
  #
  def tokenize(<<"^", blob :: binary>>, nil, meta) do
    {:ok, r_pin_token(meta: meta), next_col(meta), blob}
  end

  #
  # Operators
  #

  def tokenize(<<">=", blob :: binary>>, nil, meta) do
    {:ok, r_cmp_op_token(value: :gte, meta: meta), next_col(meta, 2), blob}
  end

  def tokenize(<<"<=", blob :: binary>>, nil, meta) do
    {:ok, r_cmp_op_token(value: :lte, meta: meta), next_col(meta, 2), blob}
  end

  def tokenize(<<"!~", blob :: binary>>, nil, meta) do
    {:ok, r_cmp_op_token(value: :nfuzz, meta: meta), next_col(meta, 2), blob}
  end

  def tokenize(<<">", blob :: binary>>, nil, meta) do
    {:ok, r_cmp_op_token(value: :gt, meta: meta), next_col(meta), blob}
  end

  def tokenize(<<"<", blob :: binary>>, nil, meta) do
    {:ok, r_cmp_op_token(value: :lt, meta: meta), next_col(meta), blob}
  end

  def tokenize(<<"!", blob :: binary>>, nil, meta) do
    {:ok, r_cmp_op_token(value: :neq, meta: meta), next_col(meta), blob}
  end

  def tokenize(<<"=", blob :: binary>>, nil, meta) do
    {:ok, r_cmp_op_token(value: :eq, meta: meta), next_col(meta), blob}
  end

  def tokenize(<<"~", blob :: binary>>, nil, meta) do
    {:ok, r_cmp_op_token(value: :fuzz, meta: meta), next_col(meta), blob}
  end

  #
  # Group
  #

  def tokenize(<<"(", blob :: binary>>, nil, meta) do
    case tokenize_all(blob, [], next_col(meta)) do
      {:ok, contents, new_meta, <<")", rest :: binary>>} ->
        {:ok, {:group, contents, meta}, next_col(new_meta), rest}

      {:ok, contents, new_meta, rest} ->
        {:error, {:unterminated_group, contents, new_meta, rest}}

      {:error, reason} ->
        {:error, {:invalid_group, reason, blob, meta}}
    end
  end

  #
  # Wildcards
  #

  def tokenize(<<"*", blob :: binary>>, nil, meta) do
    {:ok, r_wildcard_token(meta: meta), next_col(meta), blob}
  end

  def tokenize(<<"?", blob :: binary>>, nil, meta) do
    {:ok, r_any_char_token(meta: meta), next_col(meta), blob}
  end

  #
  # Misc
  #

  def tokenize(<<":", blob :: binary>>, nil, meta) do
    {:ok, {:pair_op, nil, meta}, next_col(meta), blob}
  end

  def tokenize(<<"..", blob :: binary>>, nil, meta) do
    {:ok, {:range_op, nil, meta}, next_col(meta, 2), blob}
  end

  def tokenize(<<",", blob :: binary>>, nil, meta) do
    {:ok, {:continuation_op, nil, meta}, next_col(meta), blob}
  end

  #
  # Everything else is just a word
  #

  def tokenize(<<blob :: binary>>, nil, meta) do
    case String.split(blob, ~r/\A([@\w_\-]+)/, include_captures: true, parts: 2) do
      ["", word, blob] ->
        {:ok, {:word, word, meta}, next_col(meta, byte_size(word)), blob}

      [blob] ->
        {:ok, {:eos, nil, meta}, meta, blob}
    end
  end

  defp trim_spaces(blob, meta, acc \\ [])

  defp trim_spaces(<<"\s", rest::binary>>, meta, acc) do
    trim_spaces(rest, %{meta | col_no: meta.col_no + 1}, ["\s" | acc])
  end

  defp trim_spaces(<<"\t", rest::binary>>, meta, acc) do
    trim_spaces(rest, %{meta | col_no: meta.col_no + 1}, ["\t" | acc])
  end

  defp trim_spaces(<<"\r\n", rest::binary>>, meta, acc) do
    trim_spaces(rest, %{meta | line_no: meta.line_no + 1, col_no: 1}, ["\r\n" | acc])
  end

  defp trim_spaces(<<"\n", rest::binary>>, meta, acc) do
    trim_spaces(rest, %{meta | line_no: meta.line_no + 1, col_no: 1}, ["\n" | acc])
  end

  defp trim_spaces(<<"\r", rest::binary>>, meta, acc) do
    trim_spaces(rest, %{meta | line_no: meta.line_no + 1, col_no: 1}, ["\r" | acc])
  end

  defp trim_spaces(rest, meta, acc) do
    {IO.iodata_to_binary(Enum.reverse(acc)), meta, rest}
  end
end
