defmodule ArtemisQL.SearchMap do
  defstruct [
    key_whitelist: %{},
    pair_transform: %{},
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

  @type pair_filter_value ::
          {:apply, module, function_name :: atom, args :: list}
          | {:type, type_or_module()}
          | {:jsonb, type_or_module(), jsonb_field::field_name(), jsonb_path::[String.t()]}
          | pair_filter_func()

  @type t :: %__MODULE__{
    key_whitelist: %{
      String.t() => field_name() | false | true,
    },
    pair_transform: %{
      field_name() => {:apply, module, function_name :: atom, args :: list} |
                      {:type, module | atom} |
                      pair_transform_func()
    },
    pair_filter: %{
      field_name() => pair_filter_value()
    },
    resolver: keyword_resolver_func()
  }
end
