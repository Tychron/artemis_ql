defmodule ArtemisQL.Tokens do
  @moduledoc """
  Decoded Tokens, not to be confused with the raw tokenizer tokens
  """
  import Record

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

  defrecord :r_null_token, :NULL, [:unused, :meta]

  defrecord :r_infinity_token, :infinity, [:unused, :meta]

  defrecord :r_space_token, :space, [:value, :meta]

  defrecord :r_word_token, :word, [:value, :meta]

  defrecord :r_quote_token, :quote, [:value, :meta]

  defrecord :r_value_token, :value, [:value, :meta]

  defrecord :r_wildcard_token, :wildcard, [:unused, :meta]

  defrecord :r_any_char_token, :any_char, [:unused, :meta]

  defrecord :r_pin_token, :pin, [:value, :meta]

  defrecord :r_pair_token, :pair, [:pair, :meta]

  defrecord :r_pair_op_token, :pair_op, [:unused, :meta]

  defrecord :r_partial_token, :partial, [:items, :meta]

  defrecord :r_and_token, :and, [:pair, :meta]

  defrecord :r_or_token, :or, [:pair, :meta]

  defrecord :r_cmp_op_token, :cmp_op, [:value, :meta]

  defrecord :r_cmp_token, :cmp, [:pair, :meta]

  defrecord :r_range_token, :range, [:pair, :meta]

  defrecord :r_list_token, :list, [:items, :meta]

  defrecord :r_group_token, :group, [:items, :meta]

  defmacro r_token() do
    quote do
      {_kind, _value, _meta}
    end
  end

  defmacro r_token(kind: kind) do
    quote do
      {unquote(kind), _value, _meta}
    end
  end

  defmacro r_token(meta: meta) do
    quote do
      {_kind, _value, unquote(meta)}
    end
  end

  defmacro r_token(kind: kind, meta: meta) do
    quote do
      {unquote(kind), _value, unquote(meta)}
    end
  end
end
