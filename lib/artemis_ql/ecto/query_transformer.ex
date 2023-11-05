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
  alias ArtemisQL.Errors.KeyNotFound
  alias ArtemisQL.Errors.InvalidEnumValue
  alias ArtemisQL.Errors.UnsupportedSearchTermForField

  import ArtemisQL.Ecto.Filters
  import ArtemisQL.Tokens

  @type search_list :: ArtemisQL.Decoder.search_list()

  @type abort_reason :: KeyNotFound.t()
                      | InvalidEnumValue.t()
                      | UnsupportedSearchTermForField.t()

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
      Enum.reduce_while(
        list,
        context,
        &handle_item(&1, &2)
      )

    case result do
      %Context{query: query} ->
        query

      {:abort, _reason} = abr ->
        abr
    end
  end

  defp handle_item(
    r_and_token(pair: {a, b}),
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
    r_token(kind: kind, meta: meta) = token,
    %Context{} = context
  ) when kind in [:partial, :word, :quote, :range, :list, :cmp, :group] do
    result =
      case context.search_map do
        %SearchMap{resolver: nil} ->
          {:abort, :no_resolver}

        %SearchMap{resolver: resolver} ->
          resolver.(context.query, token)

        module when is_atom(module) ->
          module.resolve(context.query, token)
      end

    case result do
      {:abort, reason} ->
        {:halt, {:abort, reason}}

      {:ok, query, key, r_token() = value} ->
        context = %{context | query: query}
        handle_item(
          r_pair_token(pair: {r_quote_token(value: to_string(key)), value}, meta: meta),
          context
        )

      %Ecto.Query{} = query ->
        {:cont, %{context | query: query}}

      schema when is_atom(schema) and not is_boolean(schema) ->
        {:cont, %{context | query: schema}}
    end
  end

  defp handle_item(
    r_pair_token(pair: {{key_kind, key, _}, value_token}) = token,
    %Context{} = context
  ) when key_kind in [:word, :quote] do
    case Types.allowed_key(key, context.search_map) do
      :missing ->
        case Keyword.get(context.options, :allow_missing, false) do
          true ->
            {:cont, context}

          false ->
            reason = %KeyNotFound{
              meta: %{
                fn: :handle_item,
              },
              key: key,
              token: token,
              search_map: context.search_map,
            }

            {:halt, {:abort, reason}}
        end

      :skip ->
        {:cont, context}

      {:ok, key} ->
        case Types.transform_pair(key, value_token, context.search_map) do
          {:ok, key, value} ->
            case apply_before_filter(key, value_token, context) do
              :reject ->
                {:halt, {:abort, :reject}}

              {:ok, %Context{} = context} ->
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

  defp handle_apply_pair_filter_result({:assoc, module_or_type, assoc_name}, query, field_name, value) do
    apply_type_filter(module_or_type, query, {:assoc, assoc_name, field_name}, value)
  end

  defp handle_apply_pair_filter_result({:assoc, module_or_type, assoc_name, field_name}, query, _key, value) do
    apply_type_filter(module_or_type, query, {:assoc, assoc_name, field_name}, value)
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
