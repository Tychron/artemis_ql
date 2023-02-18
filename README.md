# ArtemisQL

Artermis QL is a search query parser and generator.

## Usage

```
%ArtemisQL.SearchMap{
  key_whitelist: %{
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
