defmodule ArtemisQL.Tokenizer do
  @typedoc """
  All comparison operators recognized by the tokenizer

  Operators:
  * `gte` - `>=`, greater than or equal to
  * `lte` - `<=`, less than or equal to
  * `gt` - `>`, greater than
  * `lt` - `<`, less than
  * `neq` - `!`, not equal to
  * `eq` - `=`, equal to
  """
  @type comparison_operator :: :gte
                             | :lte
                             | :gt
                             | :lt
                             | :neq
                             | :eq

  @typedoc """
  End-of-Stream token, used to mark the end of a search string
  """
  @type eos_token :: :eos

  @typedoc """
  Used to represent 1 or more spaces, this includes normal whitespace, tabs, newlines and
  carriage returns.
  """
  @type space_token :: :space

  @typedoc """
  A quoted string is any number of characters originally enclosed in double-quotes ('"')
  """
  @type quoted_string_token :: {:quote, String.t()}

  @typedoc """
  A comparison operator, normally used to add some additional conditional to the value.
  """
  @type comparison_token :: {:cmp, comparison_operator()}

  @typedoc """
  The wildcard token is denoted by `*` and generally means match anything, if its used
  within a set of words or quotes then it acts as a positional matcher.
  """
  @type wildcard_token :: :wildcard

  @typedoc """
  The any_char token is denoted by `?`, it will match any one character in a string.
  """
  @type any_char_token :: :any_char

  @typedoc """
  The pair operator token is used to denote key:value pairs
  """
  @type pair_op_token :: :pair_op

  @typedoc """
  The range operator token is used to denote range pairs (e.g. `1..2`, `1..`, `..2`)
  """
  @type range_op_token :: :range_op

  @typedoc """
  The continuation operator is used to denote lists (e.g. `1,2,3,4`)
  """
  @type continuation_op_token :: :continuation_op

  @typedoc """
  A word is any unbroken text excluding special characters (only `_` and `-` are allowed)
  """
  @type word_token :: {:word, String.t()}

  @typedoc """
  Exported tokens are those that will be returned from tokenize_all, this includes all tokens,
  except :eos, which is used to tell tokenize_all/2 that there are no more tokens to parse.
  """
  @type token :: space_token()
                        | quoted_string_token()
                        | comparison_token()
                        | wildcard_token()
                        | any_char_token()
                        | pair_op_token()
                        | range_op_token()
                        | continuation_op_token()
                        | word_token()

  @type tokens :: [token()]

  @typedoc """
  The 'internal' token is all tokens plus the eos token, it is strictly used for
  bare bones tokenize
  """
  @type internal_token :: eos_token() | token()

  @doc """
  Converts the given blob into a list of tokens, this function may return the remaining string if
  not everything could be parsed, it is expected that callers check the 'rest' string to ensure
  all tokens have been parsed.

  The second argument is not intended to be used by the caller, instead it is used to implement
  the recursive parsing of the blob.

  Example:

      {:ok, _tokens, ""} = tokenize_all(blob)

  """
  @spec tokenize_all(String.t(), acc::tokens()) :: {:ok, tokens(), rest::String.t()}
  def tokenize_all(blob, acc \\ []) do
    case tokenize(blob) do
      {:ok, :eos, blob} ->
        {:ok, Enum.reverse(acc), blob}

      {:ok, token, blob} ->
        tokenize_all(blob, [token | acc])
    end
  end

  @spec tokenize(String.t(), state::any()) :: {:ok, internal_token(), rest::String.t()}
  def tokenize(blob, state \\ nil)

  def tokenize(<<>>, nil) do
    {:ok, :eos, ""}
  end

  def tokenize(<<space::utf8, blob::binary>>, nil) when space in [?\s, ?\t, ?\r, ?\n] do
    {:ok, :space, String.trim_leading(blob)}
  end

  def tokenize(<<"\"", blob::binary>>, nil) do
    tokenize(blob, {:quote, []})
  end

  def tokenize("", {:quote, acc}) do
    {:error, {:unterminated_dquote, Enum.reverse(acc)}}
  end

  def tokenize(<<"\"", blob::binary>>, {:quote, acc}) do
    str = IO.iodata_to_binary(Enum.reverse(acc))
    {:ok, {:quote, str}, blob}
  end

  def tokenize(<<"\\", c :: utf8, blob::binary>>, {:quote, acc}) do
    acc =
      case c do
        ?\\ -> ["\\" | acc]
        ?" -> ["\"" | acc]
        ?0 -> ["\0" | acc]
        ?n -> ["\n" | acc]
        ?r -> ["\r" | acc]
        ?t -> ["\t" | acc]
        ?s -> ["\s" | acc]
      end

    tokenize(blob, {:quote, acc})
  end

  def tokenize(<<c::utf8, blob::binary>>, {:quote, acc}) do
    tokenize(blob, {:quote, [<<c::utf8>> | acc]})
  end

  def tokenize(<<">=", blob :: binary>>, nil) do
    {:ok, {:cmp, :gte}, blob}
  end

  def tokenize(<<"<=", blob :: binary>>, nil) do
    {:ok, {:cmp, :lte}, blob}
  end

  def tokenize(<<">", blob :: binary>>, nil) do
    {:ok, {:cmp, :gt}, blob}
  end

  def tokenize(<<"<", blob :: binary>>, nil) do
    {:ok, {:cmp, :lt}, blob}
  end

  def tokenize(<<"!", blob :: binary>>, nil) do
    {:ok, {:cmp, :neq}, blob}
  end

  def tokenize(<<"=", blob :: binary>>, nil) do
    {:ok, {:cmp, :eq}, blob}
  end

  def tokenize(<<"(", blob :: binary>>, nil) do
    case tokenize_all(blob) do
      {:ok, contents, <<")", rest :: binary>>} ->
        {:ok, {:group, contents}, rest}

      {:error, reason} ->
        {:error, {:invalid_group, reason, blob}}
    end
  end

  def tokenize(<<"*", blob :: binary>>, nil) do
    {:ok, :wildcard, blob}
  end

  def tokenize(<<"?", blob :: binary>>, nil) do
    {:ok, :any_char, blob}
  end

  def tokenize(<<":", blob :: binary>>, nil) do
    {:ok, :pair_op, blob}
  end

  def tokenize(<<"..", blob :: binary>>, nil) do
    {:ok, :range_op, blob}
  end

  def tokenize(<<",", blob :: binary>>, nil) do
    {:ok, :continuation_op, blob}
  end

  def tokenize(<<blob :: binary>>, nil) do
    case String.split(blob, ~r/\A([@\w_\-]+)/, include_captures: true, parts: 2) do
      ["", word, blob] ->
        {:ok, {:word, word}, blob}

      [blob] ->
        {:ok, :eos, blob}
    end
  end
end
