defmodule ArtemisQL.Decoder do
  @moduledoc """
  Decodes a query string into a list of tokens
  """
  import ArtemisQL.Tokenizer

  @type word_token :: ArtemisQL.Tokenizer.word_token()

  @type quoted_string_token :: ArtemisQL.Tokenizer.quoted_string_token()

  @type key_token :: word_token() | quoted_string_token()

  @type range_token :: {:range, {:infinity | key_token(), :infinity | key_token()}}

  @type list_token :: {:list, [search_item()]}

  @type pair_token :: {:pair, {key::key_token(), value::search_item()}}

  @type partial_token :: {:partial, [key_token() | :wildcard | :any_char]}

  @type search_item :: {:group, [search_item()]}
                     | {:and, {search_item(), search_item()}}
                     | {:or, {search_item(), search_item()}}
                     | {:not, search_item()}
                     | :NULL
                     | pair_token()
                     | list_token()
                     | range_token()
                     | key_token()
                     | partial_token()

  @type search_list :: [search_item()]

  @type token :: :NULL
               | :AND
               | :OR
               | :NOT
               | ArtemisQL.Tokenizer.token()

  @type tokens :: [token()]

  @doc """
  Decodes a given query string into a set of raw artemis tokens
  """
  @spec decode(String.t()) :: {:ok, search_list(), rest::String.t()} | {:error, term}
  def decode(blob) when is_binary(blob) do
    case tokenize_all(blob) do
      {:ok, tokens, rest} ->
        tokens = token_transformer(tokens, [])

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

  defp decode_all_tokens([:space | tokens], acc) do
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

  defp decode_token([token | tokens]) when token in [:AND, :OR, :NOT, :NULL] do
    {:ok, token, tokens}
  end

  defp decode_token([{:group, group_tokens} | tokens]) do
    case decode_all_tokens(group_tokens, []) do
      {:ok, group_tokens, []} ->
        {:ok, {:group, group_tokens}, tokens}

      {:error, _reason, _tokens} = err ->
        err
    end
  end

  defp decode_token([{:quote, _} = key, :pair_op | tokens]) do
    case decode_token(tokens) do
      {:ok, value, tokens} ->
        {:ok, {:pair, {key, value}}, tokens}

      {:error, _reason, _tokens} = err ->
        err
    end
  end

  defp decode_token([{:word, _} = key, :pair_op | tokens]) do
    case decode_token(tokens) do
      {:ok, value, tokens} ->
        {:ok, {:pair, {key, value}}, tokens}

      {:error, _reason, _tokens} = err ->
        err
    end
  end

  defp decode_token([{:cmp, op} | tokens]) do
    case decode_value(tokens) do
      {:ok, value, tokens} ->
        {:ok, {:cmp, {op, value}}, tokens}

      {:error, _reason, _tokens} = err ->
        err
    end
  end

  defp decode_token([:range_op | tokens]) do
    case decode_value(tokens) do
      {:ok, value, tokens} ->
        {:ok, {:range, {:infinity, value}}, tokens}

      {:error, _reason, _tokens} = err ->
        err
    end
  end

  defp decode_token(tokens) do
    case decode_value(tokens) do
      {:error, _reason, _tokens} = err ->
        err

      {:ok, left, [:range_op, :space | tokens]} ->
        {:ok, {:range, {left, :infinity}}, tokens}

      {:ok, left, [:range_op]} ->
        {:ok, {:range, {left, :infinity}}, []}

      {:ok, left, [:range_op | tokens]} ->
        case decode_value(tokens) do
          {:ok, right, tokens} ->
            {:ok, {:range, {left, right}}, tokens}

          {:error, _reason, _tokens} = err ->
            err
        end

      {:ok, value, [:continuation_op | tokens]} ->
        case decode_list(tokens) do
          {:ok, list, tokens} ->
            {:ok, {:list, [value | list]}, tokens}

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

      {:ok, token, [:continuation_op | tokens]} ->
        decode_list(tokens, [token | acc])

      {:ok, token, [:space | _rest] = tokens} ->
        {:ok, Enum.reverse([token | acc]), tokens}

      {:ok, token, []} ->
        {:ok, Enum.reverse([token | acc]), []}
    end
  end

  defp decode_value(tokens, acc \\ [])

  defp decode_value([{kind, _} = token | tokens], acc) when kind in [:word, :quote, :range, :cmp] do
    decode_value(tokens, [token | acc])
  end

  defp decode_value([{:group, _items} = token | tokens], acc) do
    case decode_token([token]) do
      {:ok, {:group, items}, []} ->
        decode_value(tokens, [{:group, items} | acc])
    end
  end

  defp decode_value([token | tokens], acc) when token in [:wildcard, :any_char, :NULL] do
    decode_value(tokens, [token | acc])
  end

  defp decode_value(tokens, [value]) do
    {:ok, value, tokens}
  end

  defp decode_value(tokens, []) do
    {:error, :no_valid_value_type, tokens}
  end

  defp decode_value(tokens, acc) do
    {:ok, {:partial, Enum.reverse(acc)}, tokens}
  end

  defp maybe_compact_value({:group, list}) do
    case logical_compaction(list) do
      {:ok, list} ->
        list
    end
  end

  defp maybe_compact_value(token) do
    token
  end

  defp logical_compaction(tokens)

  defp logical_compaction([a, :AND | tokens]) do
    case logical_compaction(tokens) do
      {:ok, b} ->
        {:ok, [{:and, {maybe_compact_value(a), b}}]}
    end
  end

  defp logical_compaction([a, :OR | tokens]) do
    case logical_compaction(tokens) do
      {:ok, b} ->
        {:ok, [{:or, {maybe_compact_value(a), b}}]}
    end
  end

  defp logical_compaction([:NOT, a | tokens]) do
    case logical_compaction(tokens) do
      {:ok, tokens} ->
        {:ok, [{:not, maybe_compact_value(a)} | tokens]}
    end
  end

  defp logical_compaction(tokens) do
    {:ok, tokens}
  end

  defp token_transformer([], acc) do
    Enum.reverse(acc)
  end

  defp token_transformer([{:word, value} | tokens], acc) do
    case String.upcase(value) do
      "AND" ->
        token_transformer(tokens, [:AND | acc])

      "OR" ->
        token_transformer(tokens, [:OR | acc])

      "NOT" ->
        token_transformer(tokens, [:NOT | acc])

      "NULL" ->
        token_transformer(tokens, [:NULL | acc])

      _ ->
        token_transformer(tokens, [{:word, value} | acc])
    end
  end

  defp token_transformer([{:group, group_tokens} | tokens], acc) do
    token_transformer(tokens, [{:group, token_transformer(group_tokens, [])} | acc])
  end

  defp token_transformer([token | tokens], acc) do
    token_transformer(tokens, [token | acc])
  end
end
