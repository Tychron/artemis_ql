# 0.5.0

* ?

# 0.4.0

* Added new `fuzz` and `nfuzz` operators, primarily to be used by the query list to support fuzzy or partial matches where wildcards are impossible to construct normally.

```
key:~something
```

* Added field pin value, this allows comparing against another field

```
key:^other_key
```

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
