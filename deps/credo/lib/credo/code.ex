defmodule Credo.Code do
  @moduledoc """
  `Credo.Code` contains a lot of utility or helper functions that deal with the
  analysis of - you guessed it - code.

  Whenever a function serves a general purpose in this area, e.g. getting the
  value of a module attribute inside a given module, we want to extract that
  function and put it in the `Credo.Code` namespace, so others can utilize them
  without reinventing the wheel.

  The most often utilized functions are conveniently imported to
  `Credo.Check.CodeHelper`.
  """

  alias Credo.Code.Charlists
  alias Credo.Code.Sigils
  alias Credo.Code.Strings

  alias Credo.SourceFile

  defmodule ParserError do
    @moduledoc """
    This is an internal `Issue` raised by Credo when it finds itself unable to
    parse the source code in a file.
    """
  end

  @doc """
  Prewalks a given `Credo.SourceFile`'s AST or a given AST.

  Technically this is just a wrapper around `Macro.prewalk/3`.
  """
  def prewalk(ast_or_source_file, fun, accumulator \\ [])

  def prewalk(%SourceFile{} = source_file, fun, accumulator) do
    source_file
    |> SourceFile.ast()
    |> prewalk(fun, accumulator)
  end

  def prewalk(source_ast, fun, accumulator) do
    {_, accumulated} = Macro.prewalk(source_ast, accumulator, fun)

    accumulated
  end

  @doc """
  Postwalks a given `Credo.SourceFile`'s AST or a given AST.

  Technically this is just a wrapper around `Macro.postwalk/3`.
  """
  def postwalk(ast_or_source_file, fun, accumulator \\ [])

  def postwalk(%SourceFile{} = source_file, fun, accumulator) do
    source_file
    |> SourceFile.ast()
    |> postwalk(fun, accumulator)
  end

  def postwalk(source_ast, fun, accumulator) do
    {_, accumulated} = Macro.postwalk(source_ast, accumulator, fun)

    accumulated
  end

  @doc """
  Returns an AST for a given `String` or `Credo.SourceFile`.
  """
  def ast(string_or_source_file)

  def ast(%SourceFile{filename: filename} = source_file) do
    source_file
    |> SourceFile.source()
    |> ast(filename)
  end

  @doc false
  def ast(source, filename \\ "nofilename") when is_binary(source) do
    try do
      case Code.string_to_quoted(source, line: 1, columns: true) do
        {:ok, value} ->
          {:ok, value}

        {:error, error} ->
          {:error, [issue_for(error, filename)]}
      end
    rescue
      e in UnicodeConversionError ->
        {:error, [issue_for({1, e.message, nil}, filename)]}
    end
  end

  defp issue_for({line_no, error_message, _}, filename) do
    %Credo.Issue{
      check: ParserError,
      category: :error,
      filename: filename,
      message: error_message,
      line_no: line_no
    }
  end

  @doc """
  Converts a String or `Credo.SourceFile` into a List of tuples of `{line_no, line}`.
  """
  def to_lines(string_or_source_file)

  def to_lines(%SourceFile{} = source_file) do
    source_file
    |> SourceFile.source()
    |> to_lines()
  end

  def to_lines(source) when is_binary(source) do
    source
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.map(fn {line, i} -> {i + 1, line} end)
  end

  @doc """
  Converts a String or `Credo.SourceFile` into a List of tokens using the `:elixir_tokenizer`.
  """
  def to_tokens(string_or_source_file)

  def to_tokens(%SourceFile{} = source_file) do
    source_file
    |> SourceFile.source()
    |> to_tokens()
  end

  def to_tokens(source) when is_binary(source) do
    result =
      source
      |> String.to_charlist()
      |> :elixir_tokenizer.tokenize(1, [])

    case result do
      # Elixir < 1.6
      {_, _, _, tokens} ->
        tokens

      # Elixir >= 1.6
      {:ok, tokens} ->
        tokens
    end
  end

  @doc """
  Returns true if the given `child` AST node is part of the larger
  `parent` AST node.
  """
  def contains_child?(parent, child) do
    Credo.Code.prewalk(parent, &find_child(&1, &2, child), false)
  end

  defp find_child(parent, acc, child), do: {parent, acc || parent == child}

  @doc """
  Takes a SourceFile and returns its source code stripped of all Strings and
  Sigils.
  """
  def clean_charlists_strings_and_sigils(%SourceFile{} = source_file) do
    source_file
    |> SourceFile.source()
    |> clean_charlists_strings_and_sigils
  end

  def clean_charlists_strings_and_sigils(source) do
    source
    |> Sigils.replace_with_spaces()
    |> Strings.replace_with_spaces()
    |> Charlists.replace_with_spaces()
  end

  @doc """
  Takes a SourceFile and returns its source code stripped of all Strings, Sigils
  and code comments.
  """
  def clean_charlists_strings_sigils_and_comments(source, sigil_replacement \\ " ")

  def clean_charlists_strings_sigils_and_comments(%SourceFile{} = source_file, sigil_replacement) do
    source_file
    |> SourceFile.source()
    |> clean_charlists_strings_sigils_and_comments(sigil_replacement)
  end

  def clean_charlists_strings_sigils_and_comments(source, sigil_replacement) do
    source
    |> Sigils.replace_with_spaces(sigil_replacement)
    |> Strings.replace_with_spaces()
    |> Charlists.replace_with_spaces()
    |> String.replace(~r/(\A|[^\?])#.+/, "\\1")
  end

  @doc """
  Returns an AST without its metadata.
  """
  def remove_metadata(ast) when is_tuple(ast) do
    update_metadata(ast, fn _ast -> [] end)
  end

  def remove_metadata(ast) do
    ast
    |> List.wrap()
    |> Enum.map(&update_metadata(&1, fn _ast -> [] end))
  end

  defp update_metadata({atom, _meta, list} = ast, fun) when is_list(list) do
    {atom, fun.(ast), Enum.map(list, &update_metadata(&1, fun))}
  end

  defp update_metadata([do: tuple], fun) when is_tuple(tuple) do
    [do: update_metadata(tuple, fun)]
  end

  defp update_metadata([do: tuple, else: tuple2], fun) when is_tuple(tuple) do
    [do: update_metadata(tuple, fun), else: update_metadata(tuple2, fun)]
  end

  defp update_metadata({:do, tuple}, fun) when is_tuple(tuple) do
    {:do, update_metadata(tuple, fun)}
  end

  defp update_metadata({:else, tuple}, fun) when is_tuple(tuple) do
    {:else, update_metadata(tuple, fun)}
  end

  defp update_metadata({atom, _meta, arguments} = ast, fun) do
    {atom, fun.(ast), arguments}
  end

  defp update_metadata(v, fun) when is_list(v), do: Enum.map(v, &update_metadata(&1, fun))

  defp update_metadata(tuple, fun) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.map(&update_metadata(&1, fun))
    |> List.to_tuple()
  end

  defp update_metadata(v, _fun)
       when is_atom(v) or is_binary(v) or is_float(v) or is_integer(v),
       do: v
end
