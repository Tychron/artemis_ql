defmodule ArtemisQL.Mapper do
  @moduledoc """
  Utility functions for transforming list of query items into search lists
  """

  @type query_op :: :gt | :gte | :lt | :lte | :eq | :neq | :in

  @typedoc """
  Represents a partial (i.e. string that contains wildcards) value.

  Example:

      %{
        # "Word *?ther"
        :"$partial" => ["Word ", :wildcard, :any_char, "ther"]
      }

  """
  @type partial_value :: %{
    :"$partial" => [String.t() | :wildcard | :any_char]
  }

  @type value_or_partial :: nil | String.t() | boolean() | number() | partial_value()

  @typedoc """
  Represents any single search item, `key` and `op` are optional.

  Without a `key`, the item will be treated as a keyword term
  """
  @type query_item :: %{
    key: String.t(),
    op: query_op(),
    value: String.t() | [String.t()],
  }

  @type query_list :: [query_item()]

  @type tokens :: ArtemisQL.Decoder.tokens()

  @doc """
  Converts a query list to a search list of tokens
  """
  @spec query_list_to_search_list(query_list(), Keyword.t()) :: {:ok, tokens()}
  def query_list_to_search_list(list, options \\ []) when is_list(list) do
    do_query_list_to_search_list(list, {0, []}, options)
  end

  @spec search_list_to_query_list(tokens(), Keyword.t()) :: {:ok, query_list()}
  def search_list_to_query_list(list, options \\ []) do
    do_search_list_to_query_list(list, {0, []}, options)
  end

  @spec search_item_to_query_item(any(), Keyword.t()) :: {:ok, any()}
  def search_item_to_query_item(item, options) do
    do_search_item_to_query_item(item, options)
  end

  @spec cast_query_list(list() | String.t(), Keyword.t()) :: {:ok, query_list()}
  def cast_query_list(list, options \\ []) when is_list(list) do
    do_cast_query_list(list, {0, []}, options)
  end

  @spec cast_query_item(map(), Keyword.t()) :: {:ok, query_item()}
  def cast_query_item(qi, options \\ []) when is_map(qi) do
    do_cast_query_item(qi, options)
  end

  @spec cast_query_item_value(any(), Keyword.t()) :: {:ok, any()} | {:error, term()}
  def cast_query_item_value(value, options \\ []) do
    do_cast_query_item_value(value, options)
  end

  def cast_query_item_op(op, options \\ []) do
    do_cast_query_item_op(op, options)
  end

  defp do_query_list_to_search_list([], {_idx, acc}, _options) do
    {:ok, Enum.reverse(acc)}
  end

  defp do_query_list_to_search_list([qi | rest], {idx, acc}, options) when is_map(qi) do
    case value_to_search_term(qi[:value], options) do
      {:ok, val} ->
        val =
          case qi[:op] do
            nil ->
              val

            op when op in [:eq, :neq, :gt, :gte, :lt, :lte, :in] ->
              {:cmp, {op, val}}
          end

        result =
          case qi[:key] do
            nil ->
              {:ok, val}

            key ->
              case value_to_search_term(key, options) do
                {:ok, {type, _} = key} when type in [:word, :quote] ->
                  {:ok, {:pair, {key, val}}}

                {:ok, _} ->
                  {:error, {:bad_query_list_item, {idx, {:invalid_key, {key, :unexpected}}}}}

                {:error, reason} ->
                  {:error, {:bad_query_list_item, {idx, {:invalid_key, {key, reason}}}}}
              end
          end

        case result do
          {:ok, res} ->
            do_query_list_to_search_list(rest, {idx + 1, [res | acc]}, options)

          {:error, _} = err ->
            err
        end

      {:error, reason} ->
        {:error, {:bad_query_list_item, {idx, {:bad_value, reason}}}}
    end
  end

  defp value_to_search_term(nil, _options) do
    {:ok, :NULL}
  end

  defp value_to_search_term(value, _options) when is_binary(value) do
    if ArtemisQL.Util.should_quote_string?(value) do
      {:ok, {:quote, value}}
    else
      {:ok, {:word, value}}
    end
  end

  defp value_to_search_term(value, _options) when is_boolean(value) do
    {:ok, {:word, to_string(value)}}
  end

  defp value_to_search_term(value, _options) when is_number(value) do
    {:ok, {:word, to_string(value)}}
  end

  defp value_to_search_term(value, options) when is_list(value) do
    result =
      Enum.reduce_while(value, {:ok, []}, fn item, {:ok, acc}  ->
        case value_to_search_term(item, options) do
          {:ok, value} ->
            {:cont, {:ok, [value | acc]}}

          {:error, _} = err ->
            {:halt, err}
        end
      end)

    case result do
      {:ok, list} ->
        {:ok, {:list, Enum.reverse(list)}}

      {:error, _} = err ->
        err
    end
  end

  defp value_to_search_term(%{:"$wildcard" => _}, _options) do
    {:ok, :wildcard}
  end

  defp value_to_search_term(%{:"$any_char" => _}, _options) do
    {:ok, :any_char}
  end

  defp value_to_search_term(%{:"$infinity" => _}, _options) do
    {:ok, :infinity}
  end

  defp value_to_search_term(%{:"$range" => [a, b]}, options) do
    with \
      {:ok, a} <- value_to_search_term(a, options),
      {:ok, b} <- value_to_search_term(b, options)
    do
      {:ok, {:range, {a, b}}}
    else
      {:error, reason} ->
        {:error, {:bad_range, reason}}
    end
  end

  defp value_to_search_term(%{:"$partial" => list}, options) when is_list(list) do
    result =
      list
      |> Enum.reduce_while({:ok, []}, fn
        %{:"$wildcard" => _}, {:ok, acc} ->
          {:cont, {:ok, [:wildcard | acc]}}

        %{:"$any_char" => _}, {:ok, acc} ->
          {:cont, {:ok, [:any_char | acc]}}

        :wildcard, {:ok, acc} ->
          {:cont, {:ok, [:wildcard | acc]}}

        :any_char, {:ok, acc} ->
          {:cont, {:ok, [:any_char | acc]}}

        value, {:ok, acc} when is_binary(value) or is_number(value) ->
          case value_to_search_term(value, options) do
            {:ok, token} ->
              {:cont, {:ok, [token | acc]}}

            {:error, reason} ->
              {:halt, {:bad_partial_segment, {value, reason}}}
          end

        segment, {:ok, _acc} ->
          {:halt, {:bad_partial_segment, {segment, :unexpected}}}
      end)

    case result do
      {:ok, partial} ->
        {:ok, {:partial, Enum.reverse(partial)}}

      {:error, reason} ->
        {:error, {:invalid_partial, reason}}
    end
  end

  defp do_search_list_to_query_list([], {_idx, acc}, _options) do
    {:ok, Enum.reverse(acc)}
  end

  defp do_search_list_to_query_list([item | rest], {idx, acc}, options) do
    case search_item_to_query_item(item, options) do
      {:ok, item} ->
        do_search_list_to_query_list(rest, {idx + 1, [item | acc]}, options)

      {:error, _} = err ->
        err
    end
  end

  defp do_search_item_to_query_item({:pair, {key, value}}, options) do
    result =
      case value do
        {:cmp, {op, value}} ->
          case do_search_item_term_to_query_item_term(value, options) do
            {:ok, value} ->
              {:ok, %{
                op: op,
                value: value,
              }}
          end

        value ->
          case do_search_item_term_to_query_item_term(value, options) do
            {:ok, value} ->
              {:ok, %{
                key: key,
                value: value,
              }}
          end
      end

    case result do
      {:ok, item} ->
        case do_search_item_term_to_query_item_term(key, options) do
          {:ok, key} when is_binary(key) ->
            {:ok, Map.put(item, :key, key)}

          {:error, _} = err ->
            err
        end
    end
  end

  defp do_search_item_to_query_item({:cmp, {op, value}}, options) do
    case do_search_item_term_to_query_item_term(value, options) do
      {:ok, value} ->
        {:ok, %{
          op: op,
          value: value,
        }}
    end
  end

  defp do_search_item_to_query_item(term, options) do
    case do_search_item_term_to_query_item_term(term, options) do
      {:ok, value} ->
        {:ok, %{
          value: value,
        }}
    end
  end

  defp do_search_item_term_to_query_item_term(:wildcard, _options) do
    {:ok, %{:"$wildcard" => true}}
  end

  defp do_search_item_term_to_query_item_term(:any_char, _options) do
    {:ok, %{:"$any_char" => true}}
  end

  defp do_search_item_term_to_query_item_term(:infinity, _options) do
    {:ok, %{:"$infinity" => true}}
  end

  defp do_search_item_term_to_query_item_term({:word, word}, _options) do
    {:ok, word}
  end

  defp do_search_item_term_to_query_item_term({:quote, value}, _options) do
    {:ok, value}
  end

  defp do_search_item_term_to_query_item_term({:partial, segments}, options) do
    result =
      Enum.reduce_while(segments, {:ok, []}, fn
        :wildcard, {:ok, acc} ->
          {:cont, {:ok, [%{:"$wildcard" => true} | acc]}}

        :any_char, {:ok, acc} ->
          {:cont, {:ok, [%{:"$any_char" => true} | acc]}}

        token, {:ok, acc} ->
          case do_search_item_term_to_query_item_term(token, options) do
            {:ok, item} ->
              {:cont, {:ok, [item | acc]}}

            {:error, _} = err ->
              {:halt, err}
          end
      end)

    case result do
      {:ok, partial} ->
        {:ok, %{
          :"$partial" => Enum.reverse(partial)
        }}

      {:error, _} = err ->
        err
    end
  end

  defp do_search_item_term_to_query_item_term({:range, {a, b}}, options) do
    with \
      {:ok, a} <- do_search_item_term_to_query_item_term(a, options),
      {:ok, b} <- do_search_item_term_to_query_item_term(b, options)
    do
      {:ok, %{
        :"$range" => [a, b]
      }}
    else
      {:error, _} = err ->
        err
    end
  end

  defp do_search_item_term_to_query_item_term({:list, list}, options) do
    result =
      Enum.reduce_while(list, {:ok, []}, fn item, {:ok, acc} ->
        case do_search_item_term_to_query_item_term(item, options) do
          {:ok, item} ->
            {:cont, {:ok, [item | acc]}}

          {:error, _} = err ->
            {:halt, err}
        end
      end)

    case result do
      {:ok, acc} ->
        {:ok, Enum.reverse(acc)}

      {:error, _} = err ->
        err
    end
  end

  defp do_cast_query_list([], {_idx, acc}, _options) do
    {:ok, Enum.reverse(acc)}
  end

  defp do_cast_query_list([qi | rest], {idx, acc}, options) when is_map(qi) do
    case cast_query_item(qi, options) do
      {:ok, qi} ->
        do_cast_query_list(rest, {idx + 1, [qi | acc]}, options)

      {:error, reason} ->
        {:error, {:query_list_error, {idx, reason}}}
    end
  end

  @query_item_remap %{
    # keep atoms
    :key => true,
    :op => true,
    :value => true,
    # swap strings
    "key" => :key,
    "op" => :op,
    "value" => :value,
  }

  defp do_cast_query_item(qi, options) do
    qi = ArtemisQL.Util.remap_structure(qi, @query_item_remap)

    with {:ok, value} <- cast_query_item_value(qi[:value], options),
         {:ok, op} <- cast_query_item_op(qi[:op], options) do
      qi = put_in(qi[:op], op)
      put_in(qi[:value], value)
    else
      {:error, reason} ->
        {:error, {:query_item_error, reason}}
    end
  end

  @query_item_value_remap %{
    # keep atoms
    :"$partial" => true,
    :"$wildcard" => true,
    :"$any_char" => true,
    # swap strings
    "$partial" => :"$partial",
    "$wildcard" => :"$wildcard",
    "$any_char" => :"$any_char",
  }

  defp do_cast_query_item_value(value, options) do
    case value do
      val when is_nil(val) or is_binary(val) or is_boolean(val) or is_number(val) ->
        {:ok, value}

      org_val when is_map(org_val) ->
        val = ArtemisQL.Util.remap_structure(org_val, @query_item_value_remap)

        # convert the map to a list, this is done to ensure only 1 special key is present in the
        # map, anything else is considered any error.
        case Map.to_list(val) do
          [{:"$partial", partial}] when is_list(partial) ->
            result =
              Enum.reduce_while(partial, {:ok, []}, fn item, {:ok, acc} ->
                case do_cast_query_item_value(item, options) do
                  {:ok, value} ->
                    {:cont, {:ok, [value | acc]}}

                  {:error, reason} ->
                    {:halt, {:error, {:partial_format_error, reason}}}
                end
              end)

            case result do
              {:ok, list} ->
                {:ok, %{:"$partial" => Enum.reverse(list)}}

              {:error, reason} ->
                {:error, {:query_item_value_error, reason}}
            end

          [{:"$wildcard", _}] ->
            {:ok, :wildcard}

          [{:"$any_char", _}] ->
            {:ok, :any_char}

          _ ->
            {:error, {:unexpected_map_value, org_val}}
        end

      val when is_list(val) ->
        result =
          val
          |> Enum.with_index()
          |> Enum.reduce_while({:ok, []}, fn {item, index}, {:ok, acc} ->
            case do_cast_query_item_value(item, options) do
              {:ok, item} ->
                {:cont, {:ok, [item | acc]}}

              {:error, reason} ->
                {:halt, {:error, {:list_element_error, {index, reason}}}}
            end
          end)

        case result do
          {:ok, list} ->
            {:ok, Enum.reverse(list)}

          {:error, reason} ->
            {:error, {:query_item_value_error, reason}}
        end
    end
  end

  @op_map %{
    ">=" => :gte,
    ">" => :gt,
    "<=" => :lte,
    "<" => :lt,
    "=" => :eq,
    "!" => :neq,

    "gte" => :gte,
    "gt" => :gt,
    "lte" => :lte,
    "lt" => :lt,
    "eq" => :eq,
    "neq" => :neq,

    :">=" => :gte,
    :">" => :gt,
    :"<=" => :lte,
    :"<" => :lt,
    :"=" => :eq,
    :"!" => :neq,

    :gte => :gte,
    :gt => :gt,
    :lte => :lte,
    :lt => :lt,
    :eq => :eq,
    :neq => :neq,
  }

  defp do_cast_query_item_op(nil, _options) do
    {:ok, nil}
  end

  defp do_cast_query_item_op(op, _options) do
    case Map.fetch(@op_map, op) do
      {:ok, _} = res ->
        res

      :error ->
        {:error, {:bad_operator_value, op}}
    end
  end
end
