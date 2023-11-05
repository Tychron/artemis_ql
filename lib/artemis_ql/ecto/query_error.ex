defmodule ArtemisQL.Ecto.QueryError do
  @moduledoc """
  A query error occurs when to_ecto_query!/4 gets an 'abort' return value from to_ecto_query/4
  """
  defexception [:reason]

  alias ArtemisQL.Encoder

  alias ArtemisQL.Errors.KeyNotFound
  alias ArtemisQL.Errors.InvalidEnumValue
  alias ArtemisQL.Errors.UnsupportedSearchTermForField

  def message(%__MODULE__{reason: %KeyNotFound{key: key}}) do
    """
    A key was specified that does not exist in the search map provided:
      key: `#{key}`
    """
  end

  def message(%__MODULE__{reason: %InvalidEnumValue{key: key, meta: %{value: value}}}) do
    """
    #{inspect value} is not a valid value for `#{key}`
    """
  end

  def message(%__MODULE__{reason: %UnsupportedSearchTermForField{key: key, token: token}}) do
    """
    `#{Encoder.encode([token])}` is not a valid search term for `#{key}`
    """
  end

  def message(%__MODULE__{reason: :keyword_required}) do
    """
    A keyword pair is required for this search.
    """
  end
end
