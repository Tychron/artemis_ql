defmodule ArtemisQL.SearchMap.Module.Builder do
  defmacro def_key_whitelist(key) do
    quote do
      @impl true
      def key_whitelist(unquote(key) = val) do
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

  @callback key_whitelist(String.t()) :: field_name() | boolean()

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
    end
  end

  defstruct [
    key_whitelist: %{},
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
    key_whitelist: %{
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
end
