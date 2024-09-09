defmodule ArtemisQL.Random do
  import ArtemisQL.Tokens

  @spec random_boolean :: boolean()
  def random_boolean do
    :rand.uniform(2) == 1
  end

  @spec random_integer(non_neg_integer()) :: non_neg_integer()
  def random_integer(0) do
    0
  end

  def random_integer(max) when max > 0 do
    :rand.uniform(max) - 1
  end

  @spec random_integer_between(mn::integer(), mx::integer()) :: integer()
  def random_integer_between(mn, mx) when mx >= mn do
    delta = mx - mn

    mn + random_integer(delta)
  end

  @spec maybe_random_integer(any()) :: integer()
  def maybe_random_integer(mn..mx//1) do
    random_integer_between(mn, mx)
  end

  def maybe_random_integer(list) when is_list(list) do
    [item] = random_from_enum(1, list)
    item
  end

  def maybe_random_integer(num) when is_integer(num) do
    num
  end

  @spec maybe_random_integer_lazy(any(), function()) :: integer()
  def maybe_random_integer_lazy(nil, fun) when is_function(fun, 0) do
    fun.()
  end

  def maybe_random_integer_lazy(val, _fun) do
    maybe_random_integer(val)
  end

  @spec random_float() :: number()
  def random_float do
    :rand.uniform()
  end

  @spec random_float(non_neg_integer()) :: number()
  def random_float(0) do
    0
  end

  def random_float(max) when max >= 0 do
    :rand.uniform() * max
  end

  @spec random_float_between(mn::number(), mx::number()) :: number()
  def random_float_between(mn, mx) when mx >= mn do
    delta = mx - mn

    mn + random_float(delta)
  end

  @spec random_decimal :: Decimal.t()
  def random_decimal do
    Decimal.from_float(random_float())
  end

  @spec random_decimal(number()) :: Decimal.t()
  def random_decimal(max) when max >= 0 do
    Decimal.from_float(random_float(max))
  end

  @spec random_decimal_between(mn::number(), mx::number()) :: Decimal.t()
  def random_decimal_between(mn, mx) do
    Decimal.from_float(random_float_between(mn, mx))
  end

  @spec random_bytes(non_neg_integer()) :: binary()
  def random_bytes(count) when count > 0 do
    :crypto.strong_rand_bytes(count)
  end

  @doc """
  Generates a random list of length `count` from given enum
  """
  @spec random_from_enum(non_neg_integer(), [any()]) :: [any()]
  def random_from_enum(count, enum) when count > 0 do
    size = Enum.count(enum)

    for _ <- 1..count do
      Enum.at(enum, :rand.uniform(size) - 1)
    end
  end

  @doc """
  Generates a random base16-like string, depending on the count provided, the string may not
  be valid after generation, and is only meant to be used as dummy data.
  """
  @spec random_base16_string(non_neg_integer(), Keyword.t()) :: String.t()
  def random_base16_string(count, options \\ []) when count > 0 do
    # to encode a single byte, 2 hex characters are needed
    # therefore to lower the number of bytes that should be generated to fulfill the generation
    # only half are needed
    half = floor(count / 2)
    half = half + rem(half, 2)

    half
    |> random_bytes()
    |> Base.encode16(options)
    |> String.slice(0, count)
  end

  @spec random_base32_string(non_neg_integer(), Keyword.t()) :: String.t()
  def random_base32_string(count, options \\ []) do
    count
    |> random_bytes()
    |> Base.encode32(options)
    |> String.slice(0, count)
  end

  @spec random_base64_string(non_neg_integer(), Keyword.t()) :: String.t()
  def random_base64_string(count, options \\ []) do
    count
    |> random_bytes()
    |> Base.encode64(options)
    |> String.slice(0, count)
  end

  @spec random_ascii_string(non_neg_integer(), Keyword.t()) :: String.t()
  def random_ascii_string(count, _options \\ []) do
    to_string(random_from_enum(count, 32..126))
  end

  @spec random_time(Keyword.t()) :: Time.t()
  def random_time(options \\ []) do
    hour = maybe_random_integer_lazy(options[:hour], fn ->
      random_integer(24)
    end)
    minute = maybe_random_integer_lazy(options[:minute], fn ->
      random_integer(60)
    end)
    second = maybe_random_integer_lazy(options[:second], fn ->
      random_integer(60)
    end)

    Time.new!(
      hour,
      minute,
      second
    )
  end

  @spec random_partial_time(Keyword.t()) :: ArtemisQL.Types.partial_time()
  def random_partial_time(options \\ []) do
    time = random_time(options)

    case :rand.uniform(2) do
      1 ->
        {:partial_time, {time.hour}}

      2 ->
        {:partial_time, {time.hour, time.minute}}
    end
  end

  @spec random_date(Keyword.t()) :: Date.t()
  def random_date(options \\ []) do
    year = maybe_random_integer_lazy(options[:year], fn ->
      1960 + random_integer(10000 - 1960)
    end)
    month = maybe_random_integer_lazy(options[:month], fn ->
      random_integer(12) + 1
    end)
    day = maybe_random_integer_lazy(options[:day], fn ->
      random_integer(Calendar.ISO.days_in_month(year, month)) + 1
    end)

    result =
      Date.new(
        year,
        month,
        day
      )

    case result do
      {:ok, date} ->
        date

      {:error, reason} ->
        throw {:error, reason, {year, month, day}}
    end
  end

  @spec random_partial_date(Keyword.t()) :: ArtemisQL.Types.partial_date()
  def random_partial_date(options \\ []) do
    date = random_date(options)

    case :rand.uniform(2) do
      1 ->
        {:partial_date, {date.year}}

      2 ->
        {:partial_date, {date.year, date.month}}
    end
  end

  @spec random_datetime(Keyword.t()) :: DateTime.t()
  def random_datetime(options \\ []) do
    DateTime.new!(random_date(options[:date] || []), random_time(options[:time] || []))
  end

  @spec random_partial_datetime(Keyword.t()) ::
    ArtemisQL.Types.partial_date()
    | ArtemisQL.Types.partial_datetime()
  def random_partial_datetime(options \\ []) do
    datetime = random_datetime(options)
    date = DateTime.to_date(datetime)

    case :rand.uniform(5) do
      1 ->
        {:partial_date, {datetime.year}}

      2 ->
        {:partial_date, {datetime.year, datetime.month}}

      3 ->
        date

      4 ->
        {:partial_datetime, date, {:partial_time, {datetime.hour}}}

      5 ->
        {:partial_datetime, date, {:partial_time, {datetime.hour, datetime.minute}}}
    end
  end

  @spec random_naive_datetime(Keyword.t()) :: NaiveDateTime.t()
  def random_naive_datetime(options \\ []) do
    NaiveDateTime.new!(random_date(options[:date] || []), random_time(options[:time] || []))
  end

  @spec random_partial_naive_datetime(Keyword.t()) ::
    ArtemisQL.Types.partial_date()
    | ArtemisQL.Types.partial_naive_datetime()
  def random_partial_naive_datetime(options \\ []) do
    datetime = random_naive_datetime(options)
    date = NaiveDateTime.to_date(datetime)

    case :rand.uniform(5) do
      1 ->
        {:partial_date, {datetime.year}}

      2 ->
        {:partial_date, {datetime.year, datetime.month}}

      3 ->
        date

      4 ->
        {:partial_naive_datetime, date, {:partial_time, {datetime.hour}}}

      5 ->
        {:partial_naive_datetime, date, {:partial_time, {datetime.hour, datetime.minute}}}
    end
  end

  def random_wildcard_partial(len) do
    str_len = len - 2

    chars =
      for _ <- 1..str_len do
        maybe_random_integer(33..126)
      end

    r_partial_token(
      items: [
        r_wildcard_token(),
        r_value_token(value: IO.iodata_to_binary(chars)),
        r_any_char_token()
      ]
    )
  end

  def random_value_of_type(type) do
    case type do
      :binary_id ->
        Ecto.UUID.generate()

      :integer ->
        ArtemisQL.Random.random_integer_between(-0x8000, 0x7FFF)

      :float ->
        ArtemisQL.Random.random_float()

      :decimal ->
        ArtemisQL.Random.random_decimal()

      :date ->
        ArtemisQL.Random.random_date()

      :time ->
        ArtemisQL.Random.random_time()

      :utc_datetime ->
        ArtemisQL.Random.random_datetime()

      :naive_datetime ->
        ArtemisQL.Random.random_naive_datetime()

      :string ->
        ArtemisQL.Random.random_ascii_string(ArtemisQL.Random.random_integer(99) + 1)

      :boolean ->
        ArtemisQL.Random.random_boolean()
    end
  end
end
