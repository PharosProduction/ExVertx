defmodule Credo.Execution.Task.ConvertCLIOptionsToConfig do
  @moduledoc false

  use Credo.Execution.Task

  alias Credo.ConfigBuilder
  alias Credo.CLI.Output.UI

  def call(exec, _opts) do
    exec
    |> ConfigBuilder.parse()
    |> start_servers_or_halt(exec)
  end

  def start_servers_or_halt({:error, error}, exec) do
    exec
    |> Execution.put_assign("#{__MODULE__}.error", error)
    |> Execution.halt()
  end

  def start_servers_or_halt(exec, _) do
    exec
    |> Execution.start_servers()
  end

  def error(exec, _opts) do
    case Execution.get_assign(exec, "#{__MODULE__}.error") do
      {:badconfig, filename, line_no, description, trigger} ->
        lines =
          filename
          |> File.read!()
          |> Credo.Code.to_lines()
          |> Enum.filter(fn {line_no2, _line} ->
            line_no2 >= line_no - 2 and line_no2 <= line_no + 2
          end)

        UI.warn([:red, :bright, "Error while loading config file!"])
        UI.warn("")

        UI.warn([:cyan, "  file: ", :reset, filename])
        UI.warn([:cyan, "  line: ", :reset, "#{line_no}"])
        UI.warn("")

        UI.warn(["  ", description, :reset, :cyan, :bright, trigger])

        UI.warn("")

        Enum.each(lines, fn {line_no2, line} ->
          color = color_list(line_no, line_no2)

          UI.warn([color, String.pad_leading("#{line_no2}", 5), :reset, "  ", color, line])
        end)

        UI.warn("")

      error ->
        IO.warn("Execution halted during #{__MODULE__}! Unrecognized error: #{inspect(error)}")
    end

    exec
  end

  defp color_list(line_no, line_no2) when line_no == line_no2, do: [:bright, :cyan]
  defp color_list(_, _), do: [:faint]
end
