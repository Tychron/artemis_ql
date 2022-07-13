defmodule ArtemisQL.Ecto.QueryError do
  @moduledoc """
  A query error occurs when to_ecto_query!/4 gets an 'abort' return value from to_ecto_query/4
  """
  defexception [:reason]

  def message(%__MODULE__{reason: {:key_not_found, key}}) do
    """
    A key was specified that does not exist in the search map provided:
      key: `#{key}`
    """
  end

  def message(%__MODULE__{reason: {:not_valid_enum_value, key, value}}) do
    """
    `#{value}` is not a valid value for #{key}
    """
  end

  def message(%__MODULE__{reason: :keyword_required}) do
    """
    A keyword pair is required for this search.
    """
  end
end
