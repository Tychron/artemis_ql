defmodule ArtemisQL.Ecto.QueryTransformer do
  alias ArtemisQL.SearchMap
  alias ArtemisQL.Types

  import ArtemisQL.Ecto.Filters

  @type search_list :: ArtemisQL.Decoder.search_list()

  @type abort_reason :: {:key_not_found, key::String.t()}
                      | {:not_valid_enum_value, term()}

  @type abort_result :: {:abort, abort_reason()}

  @spec to_ecto_query(Ecto.Query.t(), search_list, SearchMap.t(), Keyword.t()) ::
          Ecto.Query.t() | abort_result
  def to_ecto_query(query, list, search_map, options \\ []) when is_list(list) do
    Enum.reduce_while(list, query, &handle_item(&1, &2, search_map, options))
  end

  defp handle_item({:and, {a, b}}, query, search_map, options) when is_list(b) do
    case handle_item(a, query, search_map, options) do
      {:halt, _} = line ->
        line

      {:cont, query} ->
        case Enum.reduce_while(b, query, &handle_item(&1, &2, search_map, options)) do
          {:abort, reason} ->
            {:halt, {:abort, reason}}

          query ->
            {:cont, query}
        end
    end
  end

  defp handle_item({kind, _value} = pair, query, search_map, options) when kind in [:partial, :word, :quote, :range, :list, :cmp, :group] do
    case search_map.resolver.(query, pair) do
      {:abort, reason} ->
        {:halt, {:abort, reason}}

      {:ok, query, key, value} ->
        handle_item({:pair, {{:quote, to_string(key)}, value}}, query, search_map, options)

      %Ecto.Query{} = query ->
        {:cont, query}

      query when is_atom(query) ->
        {:cont, query}
    end
  end

  defp handle_item({:pair, {{key_type, key}, value}}, query, search_map, options) when key_type in [:word, :quote] do
    case Types.whitelist_key(key, search_map) do
      :missing ->
        case Keyword.get(options, :allow_missing, false) do
          true ->
            {:cont, query}

          false ->
            {:halt, {:abort, {:key_not_found, key}}}
        end

      :skip ->
        {:cont, query}

      {:ok, key} ->
        case Types.transform_pair(key, value, search_map) do
          {:ok, key, value} ->
            case apply_filter(query, key, value, search_map) do
              {:abort, reason} ->
                {:halt, {:abort, reason}}

              query ->
                {:cont, query}
            end

          {:abort, reason} ->
            {:halt, {:abort, reason}}
        end
    end
  end

  defp apply_filter(query, key, value, search_map) do
    case search_map.pair_filter[key] do
      nil ->
        query

      {:apply, module, function_name, args} ->
        :erlang.apply(module, function_name, [query, key, value | args])

      {:type, module} ->
        apply_type_filter(module, query, key, value)

      {:jsonb, module_or_type, jsonb_data_key, path} ->
        apply_type_filter(module_or_type, query, {:jsonb, jsonb_data_key, path}, value)

      func when is_function(func, 3) ->
        case func.(query, key, value) do
          {:type, type, new_key_or_field, value} ->
            apply_type_filter(type, query, new_key_or_field, value)

          other ->
            other
        end
    end
  end
end
