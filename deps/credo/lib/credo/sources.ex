defmodule Credo.Sources do
  @moduledoc """
  This module is used to find and read all source files for analysis.
  """

  alias Credo.SourceFile

  @default_sources_glob ~w(** *.{ex,exs})
  @stdin_filename "stdin"

  @doc """
  Finds sources for a given `Credo.Execution`.

  Through the `files` key, configs may contain a list of `included` and `excluded`
  patterns. For `included`, patterns can be file paths, directory paths and globs.
  For `excluded`, patterns can also be specified as regular expressions.

      iex> Sources.find(%Credo.Execution{files: %{excluded: ["not_me.ex"], included: ["*.ex"]}})

      iex> Sources.find(%Credo.Execution{files: %{excluded: [~r/messy/], included: ["lib/mix", "root.ex"]}})
  """
  def find(exec)

  def find(%Credo.Execution{read_from_stdin: true, files: %{included: [filename]}}) do
    filename
    |> source_file_from_stdin()
    |> List.wrap()
  end

  def find(%Credo.Execution{read_from_stdin: true}) do
    @stdin_filename
    |> source_file_from_stdin()
    |> List.wrap()
  end

  def find(%Credo.Execution{files: files}) do
    MapSet.new()
    |> include(files.included)
    |> exclude(files.excluded)
    |> Enum.sort()
    |> Enum.take(max_file_count())
    |> read_files()
  end

  def find(paths) when is_list(paths) do
    Enum.flat_map(paths, &find/1)
  end

  def find(path) when is_binary(path) do
    recurse_path(path)
  end

  defp max_file_count do
    max_files = System.get_env("MAX_FILES")

    if max_files do
      String.to_integer(max_files)
    else
      1_000_000
    end
  end

  defp include(files, []), do: files

  defp include(files, [path | remaining_paths]) do
    include_paths =
      path
      |> recurse_path
      |> Enum.into(MapSet.new())

    files
    |> MapSet.union(include_paths)
    |> include(remaining_paths)
  end

  defp exclude(files, []), do: files

  defp exclude(files, [pattern | remaining_patterns]) when is_list(files) do
    files
    |> Enum.into(MapSet.new())
    |> exclude([pattern | remaining_patterns])
  end

  defp exclude(files, [pattern | remaining_patterns]) when is_binary(pattern) do
    exclude_paths =
      pattern
      |> recurse_path
      |> Enum.into(MapSet.new())

    files
    |> MapSet.difference(exclude_paths)
    |> exclude(remaining_patterns)
  end

  defp exclude(files, [pattern | remaining_patterns]) do
    files
    |> Enum.reject(&String.match?(&1, pattern))
    |> exclude(remaining_patterns)
  end

  defp recurse_path(path) do
    paths =
      cond do
        File.regular?(path) ->
          [path]

        File.dir?(path) ->
          [path | @default_sources_glob]
          |> Path.join()
          |> Path.wildcard()

        true ->
          path
          |> Path.wildcard()
          |> Enum.flat_map(&recurse_path/1)
      end

    Enum.map(paths, &Path.expand/1)
  end

  defp read_files(filenames) do
    tasks = Enum.map(filenames, &Task.async(fn -> to_source_file(&1) end))

    task_dictionary =
      tasks
      |> Enum.zip(filenames)
      |> Enum.into(%{})

    tasks_with_results = Task.yield_many(tasks)

    results =
      Enum.map(tasks_with_results, fn {task, res} ->
        # Shutdown the tasks that did not reply nor exit
        {task, res || Task.shutdown(task, :brutal_kill)}
      end)

    Enum.map(results, fn
      {_task, {:ok, value}} -> value
      {task, nil} -> SourceFile.timed_out(task_dictionary[task])
    end)
  end

  defp to_source_file(filename) do
    filename
    |> File.read!()
    |> SourceFile.parse(filename)
  end

  defp source_file_from_stdin(filename) do
    SourceFile.parse(read_from_stdin!(), filename)
  end

  defp read_from_stdin! do
    {:ok, source} = read_from_stdin()
    source
  end

  defp read_from_stdin(source \\ "") do
    case IO.read(:stdio, :line) do
      {:error, reason} ->
        {:error, reason}

      :eof ->
        {:ok, source}

      data ->
        source = source <> data
        read_from_stdin(source)
    end
  end
end
