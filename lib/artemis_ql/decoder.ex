defmodule ArtemisQL.Decoder do
  @moduledoc """
  Decodes a query string into a list of tokens
  """
  import ArtemisQL.Tokenizer
  import ArtemisQL.Tokens

  @type token_meta :: ArtemisQL.Tokens.token_meta()

  @type word_token :: ArtemisQL.Tokens.word_token()

  @type quoted_string_token :: ArtemisQL.Tokens.quoted_string_token()

  @type key_token :: word_token() | quoted_string_token()

  @type infinity_token :: {:infinity, nil, token_meta()}

  @type range_token :: {:range, {infinity_token() | key_token(), infinity_token() | key_token()}, token_meta()}

  @type list_token :: {:list, [search_item()], token_meta()}

  @type pair_token :: {:pair, {key::key_token(), value::search_item()}, token_meta()}

  @type partial_token :: {:partial, [key_token() | :wildcard | :any_char], token_meta()}

  @type search_item :: {:group, [search_item()], token_meta()}
                     | {:and, {search_item(), search_item()}, token_meta()}
                     | {:or, {search_item(), search_item()}, token_meta()}
                     | {:not, search_item()}
                     | {:NULL, nil, token_meta()}
                     | pair_token()
                     | list_token()
                     | range_token()
                     | key_token()
                     | partial_token()

  @type search_list :: [search_item()]

  @type token :: {:NULL, nil, token_meta()}
               | {:AND, nil, token_meta()}
               | {:OR, nil, token_meta()}
               | {:NOT, nil, token_meta()}
               | {:pin, word_token() | quoted_string_token()}
               | word_token()
               | quoted_string_token()

  @type tokens :: [token()]

  @doc """
  Decodes a given query string into a set of raw artemis tokens
  """
  @spec decode(String.t()) :: {:ok, search_list(), rest::String.t()} | {:error, term}
  def decode(blob) when is_binary(blob) do
    case tokenize_all(blob) do
      {:ok, tokens, _meta, rest} ->
        tokens = parse_tokens(tokens, [])

        decode_and_compact_tokens(tokens, rest)

      {:error, reason} ->
        {:error, {:tokenizer_error, reason}}
    end
  end

  @spec decode_and_compact_tokens(tokens(), String.t()) ::
          {:ok, search_list(), rest::String.t()}
          | {:error, term()}
  defp decode_and_compact_tokens(tokens, rest) do
    case decode_all_tokens(tokens, []) do
      {:ok, tokens, []} ->
        case logical_compaction(tokens) do
          {:ok, tokens} ->
            {:ok, tokens, rest}
        end

      {:error, reason, _tokens} ->
        {:error, reason}
    end
  end

  defp decode_all_tokens([], acc) do
    {:ok, Enum.reverse(acc), []}
  end

  defp decode_all_tokens([r_space_token() | tokens], acc) do
    decode_all_tokens(tokens, acc)
  end

  defp decode_all_tokens(tokens, acc) do
    case decode_token(tokens) do
      {:ok, token, tokens} ->
        decode_all_tokens(tokens, [token | acc])

      {:error, _reason, _tokens} = err ->
        err
    end
  end

  defp decode_token([r_token(kind: kind) = token | tokens]) when kind in [:AND, :OR, :NOT, :NULL] do
    {:ok, token, tokens}
  end

  defp decode_token([r_group_token(items: group_tokens, meta: meta) | tokens]) do
    case decode_all_tokens(group_tokens, []) do
      {:ok, group_tokens, []} ->
        {:ok, {:group, group_tokens, meta}, tokens}

      {:error, _reason, _tokens} = err ->
        err
    end
  end

  defp decode_token([r_quote_token(meta: meta) = key_token, {:pair_op, _, _} | tokens]) do
    case decode_token(tokens) do
      {:ok, r_token() = value_token, tokens} ->
        {:ok, {:pair, {key_token, value_token}, meta}, tokens}

      {:error, _reason, _tokens} = err ->
        err
    end
  end

  defp decode_token([r_word_token(meta: meta) = key_token, {:pair_op, _, _} | tokens]) do
    case decode_token(tokens) do
      {:ok, r_token() = value, tokens} ->
        {:ok, {:pair, {key_token, value}, meta}, tokens}

      {:error, _reason, _tokens} = err ->
        err
    end
  end

  defp decode_token([r_cmp_op_token(value: op, meta: meta) | tokens]) do
    case decode_value(tokens) do
      {:ok, value, tokens} ->
        {:ok, r_cmp_token(pair: {op, value}, meta: meta), tokens}

      {:error, _reason, _tokens} = err ->
        err
    end
  end

  defp decode_token([r_token(kind: :range_op, meta: meta), r_space_token() | tokens]) do
    {:ok, {:range, {r_infinity_token(), r_infinity_token()}, meta}, tokens}
  end

  defp decode_token([r_token(kind: :range_op, meta: meta)]) do
    {:ok, {:range, {r_infinity_token(), r_infinity_token()}, meta}, []}
  end

  defp decode_token([r_token(kind: :range_op, meta: meta) | tokens]) do
    case decode_value(tokens) do
      {:ok, value, tokens} ->
        {:ok, {:range, {r_infinity_token(), value}, meta}, tokens}

      {:error, _reason, _tokens} = err ->
        err
    end
  end

  defp decode_token(tokens) do
    case decode_value(tokens) do
      {:error, _reason, _tokens} = err ->
        err

      {:ok, left, [r_token(kind: :range_op, meta: meta), r_space_token() | tokens]} ->
        {:ok, r_range_token(pair: {left, r_infinity_token()}, meta: meta), tokens}

      {:ok, left, [r_token(kind: :range_op, meta: meta)]} ->
        {:ok, r_range_token(pair: {left, r_infinity_token()}, meta: meta), []}

      {:ok, left, [r_token(kind: :range_op, meta: meta) | tokens]} ->
        case decode_value(tokens) do
          {:ok, right, tokens} ->
            {:ok, r_range_token(pair: {left, right}, meta: meta), tokens}

          {:error, _reason, _tokens} = err ->
            err
        end

      {:ok, value, [r_token(kind: :continuation_op, meta: meta) | tokens]} ->
        case decode_list(tokens) do
          {:ok, list, tokens} ->
            {:ok, r_list_token(items: [value | list], meta: meta), tokens}

          {:error, _reason, _tokens} = err ->
            err
        end

      {:ok, value, tokens} ->
        {:ok, value, tokens}
    end
  end

  defp decode_list(tokens, acc \\ []) do
    case decode_value(tokens) do
      {:error, _reason, _tokens} = err ->
        # return the error as is
        err

      {:ok, nil, tokens} ->
        {:ok, Enum.reverse(acc), tokens}

      {:ok, token, [r_token(kind: :continuation_op) | tokens]} ->
        decode_list(tokens, [token | acc])

      {:ok, token, [r_space_token() | _rest] = tokens} ->
        {:ok, Enum.reverse([token | acc]), tokens}

      {:ok, token, []} ->
        {:ok, Enum.reverse([token | acc]), []}
    end
  end

  defp decode_value(tokens, acc \\ [])

  defp decode_value(
    [r_token(kind: kind) = token | tokens],
    acc
  ) when kind in [:word, :quote, :range, :cmp, :pin] do
    decode_value(tokens, [token | acc])
  end

  defp decode_value([r_group_token() = token | tokens], acc) do
    case decode_token([token]) do
      {:ok, {:group, _items, _meta} = token, []} ->
        decode_value(tokens, [token | acc])
    end
  end

  defp decode_value(
    [r_token(kind: kind) = token | tokens],
    acc
  ) when kind in [:wildcard, :any_char, :NULL] do
    decode_value(tokens, [token | acc])
  end

  defp decode_value(tokens, [value]) do
    {:ok, value, tokens}
  end

  defp decode_value([r_token() = token | tokens], []) do
    {:error, {:no_valid_value_type, token}, tokens}
  end

  defp decode_value(tokens, acc) do
    acc = Enum.reverse(acc)
    meta =
      case acc do
        [] ->
          nil

        [r_token(meta: meta) | _] ->
          meta
      end

    {:ok, r_partial_token(items: acc, meta: meta), tokens}
  end

  defp maybe_compact_value({:group, list, _meta}) do
    case logical_compaction(list) do
      {:ok, list} ->
        list
    end
  end

  defp maybe_compact_value(token) do
    token
  end

  defp logical_compaction(tokens)

  defp logical_compaction([a, {:AND, _, meta} | tokens]) do
    case logical_compaction(tokens) do
      {:ok, b} ->
        {:ok, [{:and, {maybe_compact_value(a), b}, meta}]}
    end
  end

  defp logical_compaction([a, {:OR, _, meta} | tokens]) do
    case logical_compaction(tokens) do
      {:ok, b} ->
        {:ok, [{:or, {maybe_compact_value(a), b}, meta}]}
    end
  end

  defp logical_compaction([{:NOT, _, meta}, a | tokens]) do
    case logical_compaction(tokens) do
      {:ok, tokens} ->
        {:ok, [{:not, maybe_compact_value(a), meta} | tokens]}
    end
  end

  defp logical_compaction(tokens) do
    {:ok, tokens}
  end

  defp parse_tokens([], acc) do
    Enum.reverse(acc)
  end

  defp parse_tokens([
    r_pin_token(meta: meta),
    {kind, _value, _meta} = token | tokens],
    acc
  ) when kind in [:word, :quote] do
    parse_tokens(tokens, [r_pin_token(value: token, meta: meta) | acc])
  end

  defp parse_tokens([r_word_token(value: value, meta: meta) | tokens], acc) do
    case String.upcase(value) do
      "AND" ->
        parse_tokens(tokens, [{:AND, value, meta} | acc])

      "OR" ->
        parse_tokens(tokens, [{:OR, value, meta} | acc])

      "NOT" ->
        parse_tokens(tokens, [{:NOT, value, meta} | acc])

      "NULL" ->
        parse_tokens(tokens, [{:NULL, value, meta} | acc])

      _ ->
        parse_tokens(tokens, [{:word, value, meta} | acc])
    end
  end

  defp parse_tokens([r_group_token(items: group_tokens, meta: meta) | tokens], acc) do
    parse_tokens(
      tokens,
      [r_group_token(items: parse_tokens(group_tokens, []), meta: meta) | acc]
    )
  end

  defp parse_tokens([token | tokens], acc) do
    parse_tokens(tokens, [token | acc])
  end
end
