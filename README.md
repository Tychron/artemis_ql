# ArtemisQL

Artermis QL is a search query parser and generator.

## Usage

```
%ArtemisQL.SearchMap{
  allowed_keys: %{
    "id" => true,
  },
  pair_transform: %{
    id: {:type, :binary_id},
  },
  pair_filter: %{
    id: {:type, :string},
  },
}
```
