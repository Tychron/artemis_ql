defmodule ArtemisQL.Errors.KeyNotFound do
  defstruct [
    key: nil,
    token: nil,
    search_map: nil,
    meta: %{},
  ]

  @type t :: %__MODULE__{}
end

defmodule ArtemisQL.Errors.InvalidEnumValue do
  defstruct [
    key: nil,
    token: nil,
    search_map: nil,
    meta: %{},
  ]

  @type t :: %__MODULE__{}
end

defmodule ArtemisQL.Errors.UnsupportedSearchTermForField do
  defstruct [
    key: nil,
    token: nil,
    search_map: nil,
    meta: %{},
  ]

  @type t :: %__MODULE__{}
end
