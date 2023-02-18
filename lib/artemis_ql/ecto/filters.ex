defmodule ArtemisQL.Ecto.Filters do
  def apply_type_filter(type, query, {:assoc, _assoc_name, _field_name} = key, value) do
    ArtemisQL.Ecto.Filters.Assoc.apply_type_filter(type, query, key, value)
  end

  def apply_type_filter(type, query, {:jsonb, _key, _path} = key, value) do
    ArtemisQL.Ecto.Filters.JSONB.apply_type_filter(type, query, key, value)
  end

  def apply_type_filter(type, query, key, value) when is_binary(key) or is_atom(key) do
    ArtemisQL.Ecto.Filters.Plain.apply_type_filter(type, query, key, value)
  end
end
