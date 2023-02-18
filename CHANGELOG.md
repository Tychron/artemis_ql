# 0.3.0

* Support for associations using:
```elixir
{:assoc, type_or_module, assoc_name}
{:assoc, type_or_module, assoc_name, field_name}

# When the filter key is the name of the field to pull from
%{
  name: {:assoc, :string, :account}
}

# When the filter key is different from the association's field
%{
  account_name: {:assoc, :string, :account, :name}
}
```
