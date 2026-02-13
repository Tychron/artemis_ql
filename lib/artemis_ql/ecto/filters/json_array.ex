defmodule ArtemisQL.Ecto.Filters.JsonArray do
  import Ecto.Query
  # import ArtemisQL.Types
  import ArtemisQL.Tokens
  import ArtemisQL.Ecto.Util

  # @date_or_time_types [:date, :time, :datetime, :utc_datetime, :naive_datetime]

  #
  # Scalars
  #
  @scalars [:binary_id, :integer, :float, :atom, :string, :decimal, :boolean]

  def apply_type_filter(_type, query, key, r_null_token()) do
    query
    |> where([m], is_nil(field(m, ^key)))
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_partial_token() = token
  ) do
    apply_type_filter(type, query, key, r_list_token(items: [token]))
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_list_token(items: items)
  ) when type in @scalars do
    handle_array_list_query(query, dynamic([m], field(m, ^key)), items)
  end

  def apply_type_filter(
    type,
    query,
    key,
    r_value_token(value: value)
  ) when type in @scalars do
    query
    |> where([m], fragment("? @> ?", field(m, ^key), ^value))
  end
end
