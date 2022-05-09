defmodule ArtemisQL do
  defmodule DecodeError do
    defexception [:reason]

    @impl true
    def message(%__MODULE__{reason: :no_valid_value_type}) do
      """
      There was a problem decoding the presented search query, this is normally caused by using
      colons after a pair and comparison operator.

      Example:
        inserted_at:<=18:26:12

      One would expect that 18:26:12 would be treated as a single string, but in reality it is
      treated as a 'pair' chain, to resolve this, simple quote the value.

      Example:
        inserted_at:<="18:26:12"
      """
    end
  end

  @moduledoc """
  Artemis QL is a search query parser and generator

  Example:

    word AND other_word OR "quoted string" NOT (a or B) AND date:2019.. OR inserted_at:..2020-01-25

  Spec:

    Artemis takes ideas from lucene and other query formats

  Items:

    Explicit nil or null - special keyword for specifying a NULL or nil

      Format:
        null

      Examples:
        null

      Output:
        :nil

    word - words are character strings without spaces

      Format:
        <word>

      Examples:
        Egg

      Output:
        {:word, value}
        {:word, "Word"}

    quoted - a quoted value is a character string encapsulated in double-quotes (")

      Format:
        "<characters>"

      Examples:
        "Egg"
        "Hello, World"

      Output:
        {:quote, value}
        {:quote, "This is a string"}

    pair - a pair is a word followed by a colon and then a value

      Format:
        key:value

      Examples:
        date:2019-01-20
        name:"This is my name"

      Output:
        {:pair, {key, value}}
        {:pair, {{:word, "Key"}, {:word, "Value"}}}
        {:pair, {{:quote, "this is a key with spaces"}, {:quote, "And a value"}}}

    comparison operators - comparison operators are prefixed to a value to change it's
                           matching behaviour.
                           When no comparison operator is specified, the value is matched using
                           whatever value is there.
                           It is up to the implementor to decide the default matching behaviour.

      Format:
        <op><value>

      Examples:
        >=value (gte)
        >value (gt)
        <value (lt)
        <=value (lte)
        =value (eq)
        !value (neq)

      Examples (in pairs):
        date:>=2019-01-20

      Output:
        {:cmp, {op, value}}
        {:cmp, {:gte, {:word, "2019-01-20"}}}

    wildcards - wildcards are special characters that denote a pattern
                they can be placed anywhere in a value stream or between words
                if placed inside a quote, it will be treated as a part of the string
                instead of as a wildcard.
                If a wildcard is used, it will output a partial tuple which will contain the parts

      Format:
        *
        ?

      Examples:
        word*
        "My name is "*
        "John "?". Doe"

      Output:
        {:partial, parts}
        {:partial, [{:word, "word"}, :wildcard]}
        {:partial, [{:quote, "My name is "}, :wildcard]}
        {:partial, [{:quote, "John "}, :any_char, {:quote, ". Doe"}]}

    logical operators

      List:
        AND
          Format:
            <value> AND <value>

        NOT
          Format:
            NOT <value>

        OR
          Format:
            <value> OR <value>

    ranges - ranges are a value followed by 2 periods (..) and then another value,
             either value may be omitted to imply an infinite range

      Format:
        <value>..
        ..<value>
        <value>..<value>

      Examples:
        2019-01-20..2020-01-19
        2019-01-20..
        ..2019-01-20

      Output:
        {:range, {{:word, "2019-01-20"}, {:word, "2020-01-19"}}}
        {:range, {{:word, "2019-01-20"}, :infinity}}
        {:range, {:infinity, {:word, "2019-01-20"}}}

    lists - lists are formed by using a comma after a value and terminated with a space or at the
            end of the string

      Format:
        <value>,<value>,<value>

      Examples:
        new,old,indifferent
        2019-01-20,2019-01-21,2019-01-22..

      Output:
        {:list, []}
        {:list, [{:word, "a"}, {:word, "b"}, {:word, "c"}]}
        {:list, [{:word, "2019-01-20"}, {:word, "2019-01-21"}, {:range, {{:word, "2019-01-22"}, :infinity}}]}

    value - a value is a word, pair, or quoted value
  """
  @spec decode(String.t()) :: {:ok, any(), rest::String.t()} | {:error, any()}
  defdelegate decode(blob), to: ArtemisQL.Decoder

  @spec encode(ArtemisQL.Decoder.search_list()) :: String.t()
  defdelegate encode(tokens), to: ArtemisQL.Encoder

  @spec to_ecto_query(Ecto.Query.t(), binary(), ArtemisQL.SearchMap.search_map(), Keyword.t()) ::
          Ecto.Query.t() | ArtemisQL.Ecto.QueryTransformer.abort_result()
  def to_ecto_query(query, binary, search_map, options \\ [])

  def to_ecto_query(query, binary, search_map, options) when is_binary(binary) do
    case decode(binary) do
      {:ok, list, _} ->
        to_ecto_query(query, list, search_map, options)

      {:error, reason} ->
        raise DecodeError, reason: reason
    end
  end

  defdelegate to_ecto_query(query, list, search_map, options), to: ArtemisQL.Ecto.QueryTransformer

  def to_ecto_query!(query, binary, search_map, options \\ []) do
    case to_ecto_query(query, binary, search_map, options) do
      {:abort, reason} ->
        raise ArtemisQL.Ecto.QueryError, reason: reason

      query ->
        query
    end
  end
end
