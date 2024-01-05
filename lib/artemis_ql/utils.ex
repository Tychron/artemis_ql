defmodule ArtemisQL.Utils do
  @type remap_field :: String.t() | atom() | {:default}

  @typedoc """
  remap key is either a string or non-nil atom, it will be used to rename a field when used as a
  value, and acts as the source field name when used as a key.

  {:default} is used to denote any missing fields, normally it would be used as {:default} => true,
  but in the case of typed maps (i.e. %{String.t() => map()}) it could be used as:

      {:default} => remap_guide

  """
  @type remap_key :: remap_field() | {:default}

  @typedoc """
  The remap value is what a field should be transformed to, if using a remap_field, it will rename
  the field, is using a boolean; when true it will keep the field name, otherwise it will drop
  the field, if using a {boolean, remap_guide} tuple, when boolean is true, it will use the sub
  remape_guide to treat the source value as a map and perform a remap_structure on it.

  Finally a {remap_field, remap_guide} can be used to change the field name AND perform a
  remap_structure on the value.
  """
  @type remap_value :: remap_field()
                     | boolean()
                     | {boolean(), remap_guide()}
                     | {remap_field(), remap_guide()}

  @typedoc """
  A remap guide is a map containing the new field names for a map or any remapping rules.
  """
  @type remap_guide :: %{
    remap_key() => remap_value()
  }

  defguard is_utf8_bom_char(c) when c == 0xFEFF
  defguard is_utf8_digit_char(c) when c >= ?0 and c <= ?9
  defguard is_utf8_scalar_char(c) when
    (c >= 0x0000 and c <= 0xD7FF) or
    (c >= 0xE000 and c <= 0x10FFFF)

  defguard is_utf8_hex_char(c) when
    (c >= ?0 and c <= ?9) or
    (c >= ?A and c <= ?F) or
    (c >= ?a and c <= ?f)

  defguard is_utf8_direction_control_char(c) when
    (c >= 0x200E and c <= 0x200F) or
    (c >= 0x2066 and c <= 0x2069) or
    (c >= 0x202A and c <= 0x202E)

  defguard is_utf8_space_like_char(c) when c in [
    0x09,
    0x0B,
    # Whitespace
    0x20,
    # No-Break Space
    0xA0,
    # Ogham Space Mark
    0x1680,
    # En Quad
    0x2000,
    # Em Quad
    0x2001,
    # En Space
    0x2002,
    # Em Space
    0x2003,
    # Three-Per-Em Space
    0x2004,
    # Four-Per-Em Space
    0x2005,
    # Six-Per-Em Space
    0x2006,
    # Figure Space
    0x2007,
    # Punctuation Space
    0x2008,
    # Thin Space
    0x2009,
    # Hair Space
    0x200A,
    # Narrow No-Break Space
    0x202F,
    # Medium Mathematical Space
    0x205F,
    # Ideographic Space
    0x3000,
  ]

  defguard is_utf8_newline_like_char(c) when c in [
    # New Line
    0x0A,
    # NP form feed, new pag
    0x0C,
    # Carriage Return
    0x0D,
    # Next-Line
    0x85,
    # Line Separator
    0x2028,
    # Paragraph Separator
    0x2029,
  ]

  defguard is_utf8_twochar_newline(c1, c2) when c1 == 0x0D and c2 == 0x0A

  @doc """
  Converts a list to a binary, this also handles tokenizer specific escape tuples.
  """
  @spec list_to_utf8_binary(list()) :: binary()
  def list_to_utf8_binary(list) when is_list(list) do
    list
    |> Enum.map(fn
      {:esc, c} when is_integer(c) -> <<c::utf8>>
      {:esc, c} when is_binary(c) -> c
      {:esc, c} when is_list(c) -> list_to_utf8_binary(c)
      c when is_integer(c) -> <<c::utf8>>
      c when is_binary(c) -> c
      c when is_list(c) -> list_to_utf8_binary(c)
    end)
    |> IO.iodata_to_binary()
  end

  @doc """
  Splits off as many space characters as possible
  """
  @spec split_spaces(binary(), list()) :: {spaces::binary(), rest::binary()}
  def split_spaces(rest, acc \\ [])

  def split_spaces(<<>> = rest, acc) do
    {list_to_utf8_binary(Enum.reverse(acc)), rest}
  end

  def split_spaces(<<c::utf8, rest::binary>>, acc) when is_utf8_space_like_char(c) do
    split_spaces(rest, [c | acc])
  end

  def split_spaces(rest, acc) do
    {list_to_utf8_binary(Enum.reverse(acc)), rest}
  end

  def split_spaces_and_newlines(rest, acc \\ [])

  def split_spaces_and_newlines(<<c::utf8, rest::binary>>, acc) when is_utf8_space_like_char(c) do
    split_spaces_and_newlines(rest, [c | acc])
  end

  def split_spaces_and_newlines(<<c1::utf8, c2::utf8, rest::binary>>, acc) when is_utf8_twochar_newline(c1, c2) do
    split_spaces_and_newlines(rest, [c2, c1 | acc])
  end

  def split_spaces_and_newlines(<<c::utf8, rest::binary>>, acc) when is_utf8_newline_like_char(c) do
    split_spaces_and_newlines(rest, [c | acc])
  end

  def split_spaces_and_newlines(rest, acc) do
    {list_to_utf8_binary(Enum.reverse(acc)), rest}
  end

  @doc """
  Renames fields in a map, supports nesting and default

  Args:
  * `input` - the input map or nil value
  * `guide` - the guide map that will be used to transform the input
  """
  @spec remap_structure(map() | nil, remap_guide()) :: map() | nil
  def remap_structure(nil, _guide) do
    nil
  end

  def remap_structure(input, guide) when is_map(input) and is_map(guide) do
    default = Map.get(guide, {:default})

    Enum.reduce(input, %{}, fn {key, value}, acc ->
      case Map.get(guide, key, default) do
        nil ->
          acc

        false ->
          acc

        true ->
          Map.put(acc, key, value)

        name when is_binary(name) or is_atom(name) ->
          Map.put(acc, name, value)

        sub_guide when is_map(sub_guide) ->
          Map.put(acc, key, remap_structure(value, sub_guide))

        {false, _sub_guide} ->
          acc

        {true, sub_guide} ->
          Map.put(acc, key, remap_structure(value, sub_guide))

        {name, sub_guide} when is_binary(name) or is_atom(name) ->
          Map.put(acc, name, remap_structure(value, sub_guide))
      end
    end)
  end

  @spec escape_quoted_string(String.t()) :: iolist()
  def escape_quoted_string(str) do
    do_escape_quoted_string(str, [])
  end

  defp do_escape_quoted_string("", acc) do
    Enum.reverse(acc)
  end

  defp do_escape_quoted_string(<<c::utf8, rest::binary>>, acc) when c in [?", ?.] do
    do_escape_quoted_string(rest, [<<c::utf8>>, "\\" | acc])
  end

  defp do_escape_quoted_string(<<"\n", rest::binary>>, acc) do
    do_escape_quoted_string(rest, ["\\n" | acc])
  end

  defp do_escape_quoted_string(<<"\r", rest::binary>>, acc) do
    do_escape_quoted_string(rest, ["\\r" | acc])
  end

  defp do_escape_quoted_string(<<c::utf8, rest::binary>>, acc) when is_utf8_newline_like_char(c) do
    hex = Integer.to_string(c, 16)
    do_escape_quoted_string(rest, ["}", hex, "\\u{" | acc])
  end

  defp do_escape_quoted_string(<<c::utf8, rest::binary>>, acc) do
    do_escape_quoted_string(rest, [<<c::utf8>> | acc])
  end

  def should_quote_string?("") do
    false
  end

  def should_quote_string?(<<"\"", _rest::binary>>) do
    true
  end

  def should_quote_string?(<<c::utf8, _rest::binary>>) when is_utf8_space_like_char(c) do
    true
  end

  def should_quote_string?(<<c::utf8, _rest::binary>>) when is_utf8_newline_like_char(c) do
    true
  end

  def should_quote_string?(<<c::utf8, _rest::binary>>) when c in [?,, ?:, ?(, ?)] do
    true
  end

  def should_quote_string?(<<_c::utf8, rest::binary>>) do
    should_quote_string?(rest)
  end
end
