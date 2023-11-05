defmodule ArtemisQL.SearchMap.Module.Builder do
  defmacro def_allowed_key(key) do
    quote do
      @impl true
      def allowed_key(unquote(key) = val) do
        String.to_existing_atom(val)
      end
    end
  end

  defmacro def_pair_transform(key, type) do
    quote do
      @impl true
      def pair_transform(unquote(key), _value), do: unquote(type)
    end
  end

  defmacro def_pair_filter(key, type) do
    quote do
      @impl true
      def pair_filter(_query, unquote(key), _value), do: unquote(type)
    end
  end
end

defmodule ArtemisQL.SearchMap.IModule do
  @type field_name :: atom()

  @type type_or_module :: atom() | module()

  @callback allowed_key(String.t()) :: nil | field_name() | boolean()

  @callback pair_transform(field_name(), value::any()) ::
    {:ok, field_name(), value::any()}
    | {:apply, module(), function_name::atom(), args::list()}
    | {:type, type_or_module()}
    | :reject

  @callback before_filter(Ecto.Query.t(), field_name(), value::any(), assigns::map()) ::
    {Ecto.Query.t(), assigns::map()}
    | :reject

  @callback pair_filter(Ecto.Query.t(), field_name(), value::any()) ::
    Ecto.Query.t()
    | {:apply, module(), function_name::atom(), args::list()}
    | {:type, type_or_module()}
    | {:jsonb, type_or_module(), jsonb_field::field_name(), jsonb_path::[String.t()]}
    | {:assoc, type_or_module(), assoc_name::atom(), field_name::atom()}

  @callback resolve(Ecto.Query.t(), value::any()) ::
    Ecto.Query.t()
    | :abort
    | {:ok, query::Ecto.Query.t() | module, field_name(), value::any()}
end

defmodule ArtemisQL.SearchMap do
  defmacro __using__(_opts) do
    quote do
      import ArtemisQL.SearchMap.Module.Builder

      @behaviour ArtemisQL.SearchMap.IModule

      @impl true
      def before_filter(query, _key, _value, assigns) do
        {query, assigns}
      end

      @impl true
      def resolve(_query, _value) do
        :abort
      end

      defoverridable [before_filter: 4, resolve: 2]

      @before_compile ArtemisQL.SearchMap
    end
  end

  defstruct [
    allowed_keys: %{},
    pair_transform: %{},
    before_filter: nil,
    pair_filter: %{},
    resolver: nil
  ]

  @type field_name :: atom()

  @type type_or_module :: atom() | module()

  @type resolver_response ::
          Ecto.Query.t()
          | :abort
          | {:ok, Ecto.Query.t() | module, String.t() | atom, term}

  @type pair_transform_func ::
          ((field_name(), value :: term) -> {:ok, field_name(), value :: term} | :reject)

  @type pair_filter_func ::
          ((query :: Ecto.Query.t(), field_name(), value :: term) -> Ecto.Query.t() | :abort)

  @type keyword_resolver_func ::
          ((query :: Ecto.Query.t(), value :: term) -> resolver_response())

  @type before_filter_func ::
          (
            (query :: Ecto.Query.t(), field_name(), value::any(), assigns::map()) ->
              {Ecto.Query.t(), assigns::any()}
              | :reject
          )

  @type pair_filter_value ::
          {:apply, module, function_name :: atom, args :: list}
          | {:type, type_or_module()}
          | {:jsonb, type_or_module(), jsonb_field::field_name(), jsonb_path::[String.t()]}
          | {:assoc, type_or_module(), assoc_name::atom(), field_name::atom()}
          | pair_filter_func()

  @type t :: %__MODULE__{
    allowed_keys: %{
      String.t() => field_name() | boolean(),
    },
    pair_transform: %{
      field_name() => {:apply, module, function_name :: atom, args :: list} |
                      {:type, module | atom} |
                      pair_transform_func()
    },
    before_filter: before_filter_func(),
    pair_filter: %{
      field_name() => pair_filter_value()
    },
    resolver: keyword_resolver_func(),
  }

  @type search_map :: t() | module()

  defmacro __before_compile__(_env) do
    quote do
      @impl true
      def allowed_key(_key) do
        nil
      end
    end
  end

  defp normalize_key(key) when is_binary(key) do
    key
    |> String.downcase()
  end

  defp normalize_key(key) when is_atom(key) do
    normalize_key(Atom.to_string(key))
  end

  def suggest_keys(%__MODULE__{} = search_map, key) do
    normalized_key = normalize_key(key)

    threshold =
      if String.length(key) > 3 do
        0.834
      else
        0.77
      end

    search_map.allowed_keys
    |> Enum.map(fn {key, _} ->
      key
    end)
    |> Enum.filter(fn allowed_key ->
      String.jaro_distance(normalize_key(allowed_key), normalized_key) >= threshold
    end)
    |> Enum.sort_by(fn allowed_key ->
      String.jaro_distance(allowed_key, normalized_key)
    end)
  end

  def suggest_keys(_search_map, _key) do
    []
  end
end
