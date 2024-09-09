# Query List

The Query List format is a JSON encoded format for expressing search terms.

As its name implies, it is a list:

```json
{
  "queryList": [
    {
      "key": "inserted_at",
      "op": "eq",
      "value": "2024-04-09"
    }
  ]
}
```

## Format

A Query List Item takes the form:

```json
{
  "key": "name",
  "op": "operator",
  "value": "value"
}
```

Where `op` is optional.

Value can be a `boolean`, `string` or `number` depending on the underlying type of the field referenced by name.

Keep in mind if using a query list from GraphQL, the value will almost always be a string.

## Dollar Sign Helpers ($N)

### Logical Operators (`op`)

```javascript
{
  "queryList": [
    {
      "op": "eq" | "neq" | "gt" | "gte" | "lt" | "lte" | "fuzz" | "nfuzz"
    }
  ]
}
```

### Wildcards

Wildcards
