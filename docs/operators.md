# Operators

| Name                     | Symbol | Mapper ID |
| ----                     | ------ | --------- |
| Greater-Than             | `>`    | `gt`      |
| Greater-Than-Or-Equal-To | `>=`   | `gte`     |
| Less-Than                | `<`    | `lt`      |
| Less-Than-Or-Equal-To    | `<=`   | `lte`     |
| Equal-To                 | `=`    | `eq`      |
| Not-Equal-To             | `!`    | `neq`     |
| Fuzzy-Not-Equal-To       | `!~`   | `nfuzz`   |
| Fuzzy-Equal-To           | `~`    | `fuzz`    |

## Usage

Operators are placed immediately before a value when used in a query string:

```
>="2024-04-09"

inserted_at:>="2024-04-09"
```

It can be seen as:

```
X >= "2024-04-09"

inserted_at >= "2024-04-09"
```

## Caveats

Not all types support all operators, or may not behave the same (especially in the case of fuzz operators).

In the case of `fuzz` and `nfuzz` operators, all scalar fields will be coerced into text before apply a LIKE query on them for Ecto query generation, otherwise it's up to the implementor to implement its behaviour for their usage.

`gt`, `gte`, `lt`, `lte`, `eq`, and `neq` behave as expected for all scalar types.
