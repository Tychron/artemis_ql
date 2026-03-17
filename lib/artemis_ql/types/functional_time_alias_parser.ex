defmodule ArtemisQL.Types.FunctionalTimeAliasParser do
  @type duration_unit ::
          :seconds
          | :minutes
          | :hours
          | :days
          | :weeks
          | :months
          | :years
          | :decades
          | :centuries
          | :millennia

  @type direction :: :point | :from | :to

  @type absolute_anchor :: :today | :now | :yesterday | :tomorrow

  @type relative_anchor_direction :: :next | :last

  @type anchor_ref ::
          {:absolute, absolute_anchor()}
          | {:relative, relative_anchor_direction(), duration_unit()}

  @type duration_map :: %{
          seconds: non_neg_integer(),
          minutes: non_neg_integer(),
          hours: non_neg_integer(),
          days: non_neg_integer(),
          weeks: non_neg_integer(),
          months: non_neg_integer(),
          years: non_neg_integer(),
          decades: non_neg_integer(),
          centuries: non_neg_integer(),
          millennia: non_neg_integer()
        }

  @type spec_map :: %{
          duration: duration_map(),
          direction: direction(),
          anchor: anchor_ref()
        }

  @type lexeme ::
          :and
          | {:anchor, absolute_anchor()}
          | {:dir, :from | :to}
          | {:rel, relative_anchor_direction()}
          | {:suffix, :ago | :later}
          | {:unit, duration_unit()}
          | {:int, non_neg_integer()}

  @zero_duration %{
    seconds: 0,
    minutes: 0,
    hours: 0,
    days: 0,
    weeks: 0,
    months: 0,
    years: 0,
    decades: 0,
    centuries: 0,
    millennia: 0
  }

  @anchor_lexemes %{
    "today" => :today,
    "now" => :now,
    "yesterday" => :yesterday,
    "tomorrow" => :tomorrow
  }

  @direction_lexemes %{
    "from" => :from,
    "to" => :to,
    "till" => :to
  }

  @relative_anchor_lexemes %{
    "next" => :next,
    "last" => :last,
    "prev" => :last,
    "previous" => :last
  }

  @suffix_lexemes %{
    "ago" => :ago,
    "later" => :later
  }

  @unit_lexemes %{
    "second" => :seconds,
    "seconds" => :seconds,
    "minute" => :minutes,
    "minutes" => :minutes,
    "hour" => :hours,
    "hours" => :hours,
    "day" => :days,
    "days" => :days,
    "week" => :weeks,
    "weeks" => :weeks,
    "month" => :months,
    "months" => :months,
    "year" => :years,
    "years" => :years,
    "decade" => :decades,
    "decades" => :decades,
    "century" => :centuries,
    "centuries" => :centuries,
    "millennium" => :millennia,
    "millennia" => :millennia
  }

  @spec parse(String.t()) :: {:ok, spec_map()} | :error
  def parse(str) when is_binary(str) do
    with {:ok, tokens} <- lex(str),
         {:ok, spec, []} <- parse_expression(tokens) do
      {:ok, spec}
    else
      _ ->
        :error
    end
  end

  @spec lex(String.t()) :: {:ok, [lexeme()]} | :error
  def lex(str) when is_binary(str) do
    str =
      str
      |> String.trim()
      |> String.downcase()

    if str == "" do
      :error
    else
      str
      |> String.split("-", trim: false)
      |> Enum.reduce_while({:ok, []}, fn
        "", _acc ->
          {:halt, :error}

        segment, {:ok, acc} ->
          case lex_segment(segment) do
            {:ok, token} ->
              {:cont, {:ok, [token | acc]}}

            :error ->
              {:halt, :error}
          end
      end)
      |> case do
        {:ok, tokens} ->
          {:ok, Enum.reverse(tokens)}

        :error ->
          :error
      end
    end
  end

  @spec parse_expression([lexeme()]) :: {:ok, spec_map(), [lexeme()]} | :error
  defp parse_expression(tokens) when is_list(tokens) do
    first_success(tokens, [
      &parse_rel_duration_expression/1,
      &parse_duration_suffix_expression/1,
      &parse_duration_directional_expression/1,
      &parse_directional_anchor_expression/1,
      &parse_anchor_expression/1
    ])
  end

  defp first_success(tokens, parsers) do
    Enum.reduce_while(parsers, :error, fn parser, _ ->
      case parser.(tokens) do
        {:ok, _spec, _rest} = ok ->
          {:halt, ok}

        :error ->
          {:cont, :error}
      end
    end)
  end

  defp parse_anchor_expression(tokens) do
    with {:ok, anchor, rest} <- parse_anchor_like(tokens) do
      {:ok, new_spec(@zero_duration, :point, anchor), rest}
    else
      :error ->
        :error
    end
  end

  defp parse_directional_anchor_expression([{:dir, dir} | rest]) do
    with {:ok, anchor, rest} <- parse_anchor_like(rest) do
      {:ok, new_spec(@zero_duration, dir, anchor), rest}
    else
      :error ->
        :error
    end
  end

  defp parse_directional_anchor_expression(_tokens), do: :error

  defp parse_duration_suffix_expression(tokens) do
    with {:ok, duration, [{:suffix, suffix} | rest]} <- parse_duration_chain(tokens) do
      direction =
        case suffix do
          :ago -> :to
          :later -> :from
        end

      {:ok, new_spec(duration, direction, {:absolute, :now}), rest}
    else
      _ ->
        :error
    end
  end

  defp parse_duration_directional_expression(tokens) do
    with {:ok, duration, [{:dir, direction} | rest]} <- parse_duration_chain(tokens),
         {:ok, anchor, rest} <- parse_anchor_like(rest) do
      {:ok, new_spec(duration, direction, anchor), rest}
    else
      _ ->
        :error
    end
  end

  defp parse_rel_duration_expression([{:rel, rel} | rest]) do
    with {:ok, duration, rest} <- parse_duration_chain(rest) do
      direction =
        case rel do
          :next -> :from
          :last -> :to
        end

      {:ok, new_spec(duration, direction, {:absolute, :now}), rest}
    else
      _ ->
        :error
    end
  end

  defp parse_rel_duration_expression(_tokens), do: :error

  defp parse_anchor_like([{:anchor, anchor} | rest]) do
    {:ok, {:absolute, anchor}, rest}
  end

  defp parse_anchor_like([{:rel, rel}, {:unit, unit} | rest]) do
    {:ok, {:relative, rel, unit}, rest}
  end

  defp parse_anchor_like(_tokens), do: :error

  defp parse_duration_chain(tokens) do
    with {:ok, duration, rest} <- parse_duration(tokens) do
      parse_duration_chain_rest(rest, duration)
    else
      :error ->
        :error
    end
  end

  defp parse_duration_chain_rest([:and | rest], duration) do
    with {:ok, next_duration, rest} <- parse_duration(rest) do
      parse_duration_chain_rest(rest, merge_duration(duration, next_duration))
    else
      :error ->
        :error
    end
  end

  defp parse_duration_chain_rest(rest, duration) do
    {:ok, duration, rest}
  end

  defp parse_duration([{:int, amount}, {:unit, unit} | rest]) do
    duration =
      @zero_duration
      |> add_duration(unit, amount)

    {:ok, duration, rest}
  end

  defp parse_duration(_tokens), do: :error

  defp lex_segment("and"), do: {:ok, :and}

  defp lex_segment(segment) when is_binary(segment) do
    cond do
      Map.has_key?(@anchor_lexemes, segment) ->
        {:ok, {:anchor, Map.fetch!(@anchor_lexemes, segment)}}

      Map.has_key?(@direction_lexemes, segment) ->
        {:ok, {:dir, Map.fetch!(@direction_lexemes, segment)}}

      Map.has_key?(@relative_anchor_lexemes, segment) ->
        {:ok, {:rel, Map.fetch!(@relative_anchor_lexemes, segment)}}

      Map.has_key?(@suffix_lexemes, segment) ->
        {:ok, {:suffix, Map.fetch!(@suffix_lexemes, segment)}}

      Map.has_key?(@unit_lexemes, segment) ->
        {:ok, {:unit, Map.fetch!(@unit_lexemes, segment)}}

      true ->
        case Integer.parse(segment, 10) do
          {value, ""} when value >= 0 ->
            {:ok, {:int, value}}

          _ ->
            :error
        end
    end
  end

  defp add_duration(duration, unit, amount) do
    Map.update!(duration, unit, &(&1 + amount))
  end

  defp merge_duration(a, b) do
    Enum.reduce(a, %{}, fn {key, value}, acc ->
      Map.put(acc, key, value + b[key])
    end)
  end

  defp new_spec(duration, direction, anchor) do
    %{
      duration: duration,
      direction: direction,
      anchor: anchor
    }
  end
end
