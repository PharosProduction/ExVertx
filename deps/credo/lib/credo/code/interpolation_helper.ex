defmodule Credo.Code.InterpolationHelper do
  @moduledoc false

  alias Credo.Code.Token

  @doc false
  def replace_interpolations(source, char \\ " ") do
    positions = interpolation_positions(source)
    lines = String.split(source, "\n")

    positions
    |> Enum.reverse()
    |> Enum.reduce(lines, &replace_line(&1, &2, char))
    |> Enum.join("\n")
  end

  defp replace_line({line_no, col_start, line_no, col_end}, lines, char) do
    List.update_at(
      lines,
      line_no - 1,
      &replace_line(&1, col_start, col_end, char)
    )
  end

  defp replace_line(position, lines, char) do
    {line_no_start, col_start, line_no_end, col_end} = position

    Enum.reduce(line_no_start..line_no_end, lines, fn
      line_no, memo
      when line_no == line_no_start ->
        List.update_at(
          memo,
          line_no - 1,
          &replace_line(&1, col_start, String.length(&1) + 1, char)
        )

      line_no, memo
      when line_no == line_no_end ->
        List.update_at(
          memo,
          line_no - 1,
          &replace_line(&1, 1, col_end, char)
        )

      line_no, memo
      when line_no < line_no_end ->
        List.update_at(
          memo,
          line_no - 1,
          &replace_line(&1, 1, String.length(&1) + 1, char)
        )
    end)
  end

  defp replace_line(line, col_start, col_end, char) do
    length = max(col_end - col_start, 0)

    String.slice(line, 0, col_start - 1) <>
      String.duplicate(char, length) <> String.slice(line, (col_end - 1)..-1)
  end

  @doc false
  def interpolation_positions(source) do
    source
    |> Credo.Code.to_tokens()
    |> Enum.flat_map(&map_interpolations(&1, source))
    |> Enum.reject(&is_nil/1)
  end

  if Version.match?(System.version(), ">= 1.6.0-rc") do
    #
    # Elixir >= 1.6.0
    #

    defp map_interpolations(
           {:sigil, {_line_no, _col_start, nil}, _, list, _, _sigil_start_char} = token,
           source
         ) do
      handle_atom_string_or_sigil(token, list, source)
    end

    defp map_interpolations(
           {:bin_heredoc, {_line_no, _col_start, _}, _list} = token,
           source
         ) do
      handle_heredoc(token, source)
    end

    defp map_interpolations(
           {:bin_string, {_line_no, _col_start, _}, list} = token,
           source
         ) do
      handle_atom_string_or_sigil(token, list, source)
    end
  else
    #
    # Elixir <= 1.5.x
    #

    defp is_sigil_in_line(source, line_no) do
      line_with_heredoc_quotes = get_line(source, line_no)

      !!Regex.run(~r/("""|''')/, line_with_heredoc_quotes)
    end

    defp map_interpolations(
           {:sigil, {_line_no, _col_start, _col_end}, _, list, _} = token,
           source
         ) do
      handle_atom_string_or_sigil(token, list, source)
    end

    defp map_interpolations(
           {:bin_string, {line_no, _col_start, _}, list} = token,
           source
         ) do
      if is_sigil_in_line(source, line_no) do
        handle_heredoc(token, source)
      else
        handle_atom_string_or_sigil(token, list, source)
      end
    end
  end

  defp map_interpolations(
         {:atom_unsafe, {_line_no, _col_start, _}, list} = token,
         source
       ) do
    handle_atom_string_or_sigil(token, list, source)
  end

  defp map_interpolations(_, _source), do: []

  defp handle_atom_string_or_sigil(_token, list, source) do
    find_interpolations(list, source)
  end

  defp handle_heredoc({_atom, {line_no, _, _}, list}, source) do
    first_line_in_heredoc = get_line(source, line_no + 1)

    # TODO: this seems to be wrong. the closing """ determines the
    #       indentation, not the first line of the heredoc.
    padding_in_first_line = determine_padding_at_start_of_line(first_line_in_heredoc)

    list
    |> find_interpolations(source)
    |> Enum.reject(&is_nil/1)
    |> add_to_col_start_and_end(padding_in_first_line)
  end

  defp find_interpolations(list, source) when is_list(list) do
    Enum.map(list, &find_interpolations(&1, source))
  end

  # {{1, 25, 32}, [{:identifier, {1, 27, 31}, :name}]}
  defp find_interpolations({{_line_no, _col_start2, _}, _list} = token, source) do
    {line_no, col_start, line_no_end, col_end} = Token.position(token)

    {line_no, col_start, line_no_end, col_end}
    # |> IO.inspect()

    col_end =
      if line_no_end > line_no && col_end == 1 do
        # This means we encountered :eol and jumped in the next line.
        # We need to add the closing `}`.
        col_end + 1
      else
        col_end
      end

    line = get_line(source, line_no_end)

    # `col_end - 1` to account for the closing `}`
    rest_of_line = get_rest_of_line(line, col_end - 1)

    # IO.inspect(rest_of_line, label: "rest_of_line")

    padding = determine_padding_at_start_of_line(rest_of_line, ~r/^\s*\}/)

    # -1 to remove the accounted-for `}`
    padding = max(padding - 1, 0)

    # IO.inspect(padding, label: "padding")

    {line_no, col_start, line_no_end, col_end + padding}
  end

  defp find_interpolations(_value, _source), do: nil

  defp determine_padding_at_start_of_line(line, regex \\ ~r/^\s+/) do
    regex
    |> Regex.run(line)
    |> List.wrap()
    |> Enum.join()
    |> String.length()
  end

  defp add_to_col_start_and_end(positions, padding) do
    Enum.map(positions, fn {line_no, col_start, line_no_end, col_end} ->
      {line_no, col_start + padding, line_no_end, col_end + padding}
    end)
  end

  defp get_line(source, line_no) do
    source
    |> String.split("\n")
    |> Enum.at(line_no - 1)
  end

  defp get_rest_of_line(line, col_end) do
    # col-1 to account for col being 1-based
    start = max(col_end - 1, 0)

    String.slice(line, start..-1)
  end
end
