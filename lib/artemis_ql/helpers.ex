defmodule ArtemisQL.Helpers do
  @moduledoc """
  Various helper functions for working with tokens or some token values such as partials
  """
  import ArtemisQL.Tokens

  @spec partial_to_regex(list(), binary() | [term()]) :: {:ok, Regex.t()} | {:error, any()}
  def partial_to_regex(partial, options \\ "") when is_list(partial) do
    [
      "\\A",
      partial
      |> Enum.map(fn
        r_word_token(value: value) ->
          Regex.escape(value)

        r_quote_token(value: value) ->
          Regex.escape(value)

        r_wildcard_token() ->
          ".*"

        r_any_char_token() ->
          "."
      end),
      "\\z"
    ]
    |> IO.iodata_to_binary()
    |> Regex.compile(options)
  end

  @spec partial_to_regex!(list(), binary() | [term()]) :: Regex.t()
  def partial_to_regex!(partial, options \\ "") do
    {:ok, regex} = partial_to_regex(partial, options)
    regex
  end

  @doc """
  Compares the given string against a given partial
  """
  @spec string_matches_partial?(binary(), list(), binary() | [term()]) :: boolean()
  def string_matches_partial?(str, partial, options \\ "") when is_list(partial) do
    String.match?(str, partial_to_regex!(partial, options))
  end
end
