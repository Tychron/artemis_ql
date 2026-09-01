defmodule ArtemisQL.Ecto.QueryTransformer.Context do
  defstruct [
    search_list: nil,
    search_map: nil,
    options: nil,
    query: nil,
    assigns: nil,
  ]

  @type t :: %__MODULE__{}
end

defmodule ArtemisQL.Ecto.QueryTransformer do
  alias ArtemisQL.SearchMap
  alias ArtemisQL.Types
  alias ArtemisQL.Typecasts
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
                      | term()

  @type abort_result :: {:abort, abort_reason()}

  @spec to_ecto_query(Ecto.Query.t(), search_list(), SearchMap.t(), Keyword.t()) ::
          Ecto.Query.t()
          | abort_result()
  def to_ecto_query(query, list, search_map, options \\ []) when is_list(list) do
    {query_assigns, options} = Keyword.pop_lazy(options, :query_assigns, fn ->
      %{}
    end)

    context = %Context{
      search_list: list,
      search_map: search_map,
      query: query,
      options: options,
      assigns: query_assigns,
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
        case Enum.reduce_while(b, context, &handle_item/2) do
          {:abort, reason} ->
            {:halt, {:abort, reason}}

          %Context{} = context ->
            {:cont, context}
        end
    end
  end

  defp handle_item(
    r_or_token(),
    %Context{}
  ) do
    {:halt, {:abort, :unsupported_logical_or}}
  end

  defp handle_item(
    {:not, _item, _meta},
    %Context{}
  ) do
    {:halt, {:abort, :unsupported_logical_not}}
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
                  %Context{query: {:abort, reason}} ->
                    {:halt, {:abort, reason}}

                  %Context{} = context ->
                    {:cont, context}
                end
            end

          {:error, reason} ->
            {:halt, {:abort, reason}}

          {:abort, reason} ->
            {:halt, {:abort, reason}}

          :reject ->
            {:halt, {:abort, :reject}}
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

  @spec apply_pair_filter(atom(), any(), Context.t()) :: Context.t()
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
    with :ok <- validate_filter_value(query, key, value) do
      apply_type_filter(module, query, key, value)
    else
      {:error, reason} -> {:abort, reason}
    end
  end

  defp handle_apply_pair_filter_result({:type, type, new_key_or_field, value}, query, _key, _value) do
    with :ok <- validate_filter_value(query, new_key_or_field, value) do
      apply_type_filter(type, query, new_key_or_field, value)
    else
      {:error, reason} -> {:abort, reason}
    end
  end

  defp handle_apply_pair_filter_result({:jsonb, module_or_type, jsonb_data_key, path}, query, _key, value) do
    apply_type_filter(module_or_type, query, {:jsonb, jsonb_data_key, path}, value)
  end

  defp handle_apply_pair_filter_result({:assoc, module_or_type, assoc_name}, query, field_name, value) do
    with :ok <- validate_assoc_filter_value(query, assoc_name, field_name, value) do
      apply_type_filter(module_or_type, query, {:assoc, assoc_name, field_name}, value)
    else
      {:error, reason} -> {:abort, reason}
    end
  end

  defp handle_apply_pair_filter_result({:assoc, module_or_type, assoc_name, field_name}, query, _key, value) do
    with :ok <- validate_assoc_filter_value(query, assoc_name, field_name, value) do
      apply_type_filter(module_or_type, query, {:assoc, assoc_name, field_name}, value)
    else
      {:error, reason} -> {:abort, reason}
    end
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

  defp validate_filter_value(query, field_name, value) when is_atom(field_name) do
    case query_schema(query) do
      nil ->
        :ok

      schema ->
        validate_schema_value(schema.__schema__(:type, field_name), value)
    end
  end

  defp validate_filter_value(_query, _field_name, _value), do: :ok

  defp validate_assoc_filter_value(query, assoc_name, field_name, value) do
    with schema when not is_nil(schema) <- query_schema(query),
         %{related: related_schema} <- schema.__schema__(:association, assoc_name) do
      validate_schema_value(related_schema.__schema__(:type, field_name), value)
    else
      _ -> :ok
    end
  end

  defp validate_schema_value(nil, _value), do: :ok

  defp validate_schema_value(schema_type, value) do
    case identifier_schema_type?(schema_type) do
      true -> validate_identifier_token(value, schema_type)
      false -> :ok
    end
  end

  defp identifier_schema_type?(:binary_id), do: true

  defp identifier_schema_type?(schema_type) when is_atom(schema_type) do
    function_exported?(schema_type, :type, 0) and schema_type.type() in [:binary_id, :uuid]
  rescue
    _error -> false
  end

  defp identifier_schema_type?(_schema_type), do: false

  defp validate_identifier_token(r_value_token(value: value), schema_type) do
    validate_identifier_value(value, schema_type)
  end

  defp validate_identifier_token(r_list_token(items: items), schema_type) do
    Enum.reduce_while(items, :ok, fn item, :ok ->
      case validate_identifier_token(item, schema_type) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp validate_identifier_token(r_cmp_token(pair: {_operator, value}), schema_type) do
    validate_identifier_token(value, schema_type)
  end

  defp validate_identifier_token(r_range_token(pair: {a, b}), schema_type) do
    with :ok <- validate_identifier_token(a, schema_type),
         :ok <- validate_identifier_token(b, schema_type) do
      :ok
    end
  end

  defp validate_identifier_token(r_group_token(items: items), schema_type) do
    Enum.reduce_while(items, :ok, fn item, :ok ->
      case validate_identifier_token(item, schema_type) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp validate_identifier_token(_token, _schema_type), do: :ok

  defp validate_identifier_value(value, :binary_id) do
    case Typecasts.cast_binary_id(value) do
      {:ok, _value} -> :ok
      :error -> {:error, :cast_error}
    end
  end

  defp validate_identifier_value(value, schema_type) do
    case Ecto.Type.cast(schema_type, value) do
      {:ok, _value} -> :ok
      :error -> {:error, :cast_error}
      {:error, _reason} -> {:error, :cast_error}
    end
  rescue
    _error -> {:error, :cast_error}
  end

  defp query_schema(schema) when is_atom(schema) and not is_boolean(schema) do
    case function_exported?(schema, :__schema__, 1) do
      true -> schema
      false -> nil
    end
  end

  defp query_schema(%Ecto.Query{from: %{source: {_source, schema}}})
       when is_atom(schema) and not is_nil(schema) do
    schema
  end

  defp query_schema(_query), do: nil
end
