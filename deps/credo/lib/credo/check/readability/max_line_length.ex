defmodule Credo.Check.Readability.MaxLineLength do
  @moduledoc false

  @checkdoc """
  Checks for the length of lines.

  Ignores function definitions and (multi-)line strings by default.
  """
  @explanation [
    check: @checkdoc,
    params: [
      max_length: "The maximum number of characters a line may consist of.",
      ignore_definitions: "Set to `true` to ignore lines including function definitions.",
      ignore_specs: "Set to `true` to ignore lines including `@spec`s.",
      ignore_strings: "Set to `true` to ignore lines that are strings or in heredocs.",
      ignore_urls: "Set to `true` to ignore lines that contain urls."
    ]
  ]
  @default_params [
    max_length: 120,
    ignore_definitions: true,
    ignore_specs: false,
    ignore_strings: true,
    ignore_urls: true
  ]
  @def_ops [:def, :defp, :defmacro]
  @url_regex ~r/[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&\/\/=]*)/

  use Credo.Check, base_priority: :low

  alias Credo.Code.Heredocs
  alias Credo.Code.Strings

  @doc false
  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)
    max_length = Params.get(params, :max_length, @default_params)

    ignore_definitions = Params.get(params, :ignore_definitions, @default_params)

    ignore_specs = Params.get(params, :ignore_specs, @default_params)
    ignore_strings = Params.get(params, :ignore_strings, @default_params)
    # TODO v1.0: this should be two different params
    ignore_heredocs = ignore_strings
    ignore_urls = Params.get(params, :ignore_urls, @default_params)

    definitions = Credo.Code.prewalk(source_file, &find_definitions/2)
    specs = Credo.Code.prewalk(source_file, &find_specs/2)

    source = SourceFile.source(source_file)

    source =
      if ignore_heredocs do
        Heredocs.replace_with_spaces(source, "")
      else
        source
      end

    lines = Credo.Code.to_lines(source)

    lines_for_comparison =
      if ignore_strings do
        source
        |> Strings.replace_with_spaces("")
        |> Credo.Code.to_lines()
      else
        lines
      end

    lines_for_comparison =
      if ignore_urls do
        Enum.reject(lines_for_comparison, fn {_, line} -> line =~ @url_regex end)
      else
        lines_for_comparison
      end

    Enum.reduce(lines_for_comparison, [], fn {line_no, line_for_comparison}, issues ->
      if String.length(line_for_comparison) > max_length do
        if refute_issue?(line_no, definitions, ignore_definitions, specs, ignore_specs) do
          issues
        else
          {_, line} = Enum.at(lines, line_no - 1)

          [issue_for(line_no, max_length, line, issue_meta) | issues]
        end
      else
        issues
      end
    end)
  end

  for op <- @def_ops do
    defp find_definitions({unquote(op), meta, arguments} = ast, definitions)
         when is_list(arguments) do
      {ast, [meta[:line] | definitions]}
    end
  end

  defp find_definitions(ast, definitions) do
    {ast, definitions}
  end

  defp find_specs({:spec, meta, arguments} = ast, specs) when is_list(arguments) do
    {ast, [meta[:line] | specs]}
  end

  defp find_specs(ast, specs) do
    {ast, specs}
  end

  defp refute_issue?(line_no, definitions, ignore_definitions, specs, ignore_specs) do
    ignore_definitions? =
      if ignore_definitions do
        Enum.member?(definitions, line_no)
      else
        false
      end

    ignore_specs? =
      if ignore_specs do
        Enum.member?(specs, line_no)
      else
        false
      end

    ignore_definitions? || ignore_specs?
  end

  defp issue_for(line_no, max_length, line, issue_meta) do
    line_length = String.length(line)
    column = max_length + 1
    trigger = String.slice(line, max_length, line_length - max_length)

    format_issue(
      issue_meta,
      message: "Line is too long (max is #{max_length}, was #{line_length}).",
      line_no: line_no,
      column: column,
      trigger: trigger
    )
  end
end
