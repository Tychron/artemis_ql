# 0.7.0

## General

* Improvement to tokenizer to handle more space characters
* Quoted strings now support unicode escapes `\u{HEX}`
* Support for words with period characters (i.e. `192.168.0.1` no longer needs to be quoted)

## ArtemisQL.Helpers

* `partial_to_regex/1` > `partial_to_regex/2` now accepts Regex.compile options

# 0.6.0

This version contains changes heading towards a quality of life improvement update that will be made later.

* **Breaking Change** `key_whitelist` and related functions have been renamed to `allowed_key`, this also includes `key_whitelist` in `SearchMap` which has been renamed to `allowed_keys`
* **Breaking Change** the abort/error tuple `{:key_not_found, key}` has be dropped in favour of the `ArtemisQL.Errors.KeyNotFound` struct which contains more information about the key and its related token

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
