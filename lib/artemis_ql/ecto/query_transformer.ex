defmodule ArtemisQL.Ecto.QueryTransformer.Context do
  defstruct [
    search_list: nil,
    search_map: nil,
    options: nil,
    query: nil,
    assigns: %{},
  ]
end

defmodule ArtemisQL.Ecto.QueryTransformer do
  alias ArtemisQL.SearchMap
  alias ArtemisQL.Types
  alias ArtemisQL.Ecto.QueryTransformer.Context

  import ArtemisQL.Ecto.Filters

  @type search_list :: ArtemisQL.Decoder.search_list()

  @type abort_reason :: {:key_not_found, key::String.t()}
                      | {:not_valid_enum_value, term()}

  @type abort_result :: {:abort, abort_reason()}

  @spec to_ecto_query(Ecto.Query.t(), search_list(), SearchMap.t(), Keyword.t()) ::
          Ecto.Query.t()
          | abort_result()
  def to_ecto_query(query, list, search_map, options \\ []) when is_list(list) do
    context = %Context{
      search_list: list,
      search_map: search_map,
      query: query,
      options: options,
    }

    result =
      Enum.reduce_while(list, context, &handle_item(&1, &2))

    case result do
      %Context{query: query} ->
        query

      {:abort, _reason} = abr ->
        abr
    end
  end

  defp handle_item(
    {:and, {a, b}},
    %Context{} = context
  ) when is_list(b) do
    case handle_item(a, context) do
      {:halt, _} = line ->
        line

      {:cont, %Context{} = context} ->
        case Enum.reduce_while(b, context, &handle_item(&1, context)) do
          {:abort, reason} ->
            {:halt, {:abort, reason}}

          %Context{} = context ->
            {:cont, context}
        end
    end
  end

  defp handle_item(
    {kind, _value} = pair,
    %Context{} = context
  ) when kind in [:partial, :word, :quote, :range, :list, :cmp, :group] do
    result =
      case context.search_map do
        %SearchMap{resolver: nil} ->
          {:abort, :no_resolver}

        %SearchMap{resolver: resolver} ->
          resolver.(context.query, pair)

        module when is_atom(module) ->
          module.resolve(context.query, pair)
      end

    case result do
      {:abort, reason} ->
        {:halt, {:abort, reason}}

      {:ok, query, key, value} ->
        context = %{context | query: query}
        handle_item({:pair, {{:quote, to_string(key)}, value}}, context)

      %Ecto.Query{} = query ->
        {:cont, %{context | query: query}}

      schema when is_atom(schema) and not is_boolean(schema) ->
        {:cont, %{context | query: schema}}
    end
  end

  defp handle_item(
    {:pair, {{key_type, key}, value}},
    %Context{} = context
  ) when key_type in [:word, :quote] do
    case Types.whitelist_key(key, context.search_map) do
      :missing ->
        case Keyword.get(context.options, :allow_missing, false) do
          true ->
            {:cont, context}

          false ->
            {:halt, {:abort, {:key_not_found, key}}}
        end

      :skip ->
        {:cont, context}

      {:ok, key} ->
        case Types.transform_pair(key, value, context.search_map) do
          {:ok, key, value} ->
            case apply_before_filter(key, value, context) do
              :reject ->
                {:halt, {:abort, :reject}}

              {:ok, context} ->
                case apply_pair_filter(key, value, context) do
                  {:abort, reason} ->
                    {:halt, {:abort, reason}}

                  %Context{} = context ->
                    {:cont, context}
                end
            end

          {:abort, reason} ->
            {:halt, {:abort, reason}}
        end
    end
  end

  defp apply_before_filter(key, value, %Context{} = context) do
    case context.search_map do
      %SearchMap{before_filter: nil} ->
        {:ok, context}

      %SearchMap{before_filter: func} ->
        case func.(context.query, key, value, context.assigns) do
          {query, assigns} ->
            {:ok, %{context | query: query, assigns: assigns}}

          :reject ->
            :reject
        end

      module when is_atom(module) and not is_boolean(module) ->
        case apply(module, :before_filter, [context.query, key, value, context.assigns]) do
          {query, assigns} ->
            {:ok, %{context | query: query, assigns: assigns}}

          :reject ->
            :reject
        end
    end
  end

  defp apply_pair_filter(key, value, %Context{} = context) do
    query = context.query

    result =
      case context.search_map do
        %SearchMap{pair_filter: pair_filter} ->
          pair_filter[key]

        module when is_atom(module) ->
          apply(module, :pair_filter, [query, key, value])
      end

    query = handle_apply_pair_filter_result(result, query, key, value)

    %{context | query: query}
  end

  defp handle_apply_pair_filter_result({:abort, _reason} = abr, _query, _key, _value) do
    abr
  end

  defp handle_apply_pair_filter_result(nil, query, _key, _value) do
    query
  end

  defp handle_apply_pair_filter_result({:apply, module, function_name, args}, query, key, value) do
    handle_apply_pair_filter_result(:erlang.apply(module, function_name, [query, key, value | args]), query, key, value)
  end

  defp handle_apply_pair_filter_result({:type, module}, query, key, value) do
    apply_type_filter(module, query, key, value)
  end

  defp handle_apply_pair_filter_result({:type, type, new_key_or_field, value}, query, _key, _value) do
    apply_type_filter(type, query, new_key_or_field, value)
  end

  defp handle_apply_pair_filter_result({:jsonb, module_or_type, jsonb_data_key, path}, query, _key, value) do
    apply_type_filter(module_or_type, query, {:jsonb, jsonb_data_key, path}, value)
  end

  defp handle_apply_pair_filter_result(func, query, key, value) when is_function(func, 3) do
    handle_apply_pair_filter_result(func.(query, key, value), query, key, value)
  end

  defp handle_apply_pair_filter_result(%Ecto.Query{} = query, _old_query, _key, _value) do
    query
  end

defp handle_apply_pair_filter_result(schema, _old_query, _key, _value) when is_atom(schema) and not is_boolean(schema) do
    schema
  end
end
