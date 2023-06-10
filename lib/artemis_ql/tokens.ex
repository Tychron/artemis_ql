defmodule ArtemisQL.Tokens do
  @moduledoc """
  Decoded Tokens, not to be confused with the raw tokenizer tokens
  """
  import Record

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
