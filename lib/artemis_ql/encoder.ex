defmodule ArtemisQL.Encoder do
  @type search_list :: term

  @spec encode(search_list()) :: {:ok, String.t()} | {:error, term}
  def encode(tokens) when is_list(tokens) do
    raise "TODO"
  end
end
