defmodule ArtemisQL.Types.ValueTransformError do
  defexception [message: nil, types: [], caused_by: nil]

  @impl true
  def message(%{caused_by: nil} = exception) do
    types = Enum.join(exception.types, ", ")
    "a error occured while transforming the value (tried types: #{types})"
  end

  @impl true
  def message(%{caused_by: caused_by} = exception) do
    IO.iodata_to_binary [message(%{exception | caused_by: nil}), "\n", Exception.format(:error, caused_by)]
  end
end
