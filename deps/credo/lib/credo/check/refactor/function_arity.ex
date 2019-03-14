defmodule Credo.Check.Refactor.FunctionArity do
  @moduledoc false

  @checkdoc """
  A function can take as many parameters as needed, but even in a functional
  language there can be too many parameters.

  Can optionally ignore private functions (check configuration options).
  """
  @explanation [
    check: @checkdoc,
    params: [
      max_arity: "The maximum number of parameters which a function should take.",
      ignore_defp: "Set to `true` to ignore private functions."
    ]
  ]
  @default_params [max_arity: 8, ignore_defp: false]
  @def_ops [:def, :defp, :defmacro]

  use Credo.Check

  alias Credo.Code.Parameters

  @doc false
  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)
    max_arity = Params.get(params, :max_arity, @default_params)
    ignore_defp = Params.get(params, :ignore_defp, @default_params)

    Credo.Code.prewalk(
      source_file,
      &traverse(&1, &2, issue_meta, max_arity, ignore_defp)
    )
  end

  for op <- @def_ops do
    defp traverse(
           {unquote(op) = op, meta, arguments} = ast,
           issues,
           issue_meta,
           max_arity,
           ignore_defp
         )
         when is_list(arguments) do
      arity = Parameters.count(ast)

      if issue?(op, ignore_defp, arity, max_arity) do
        fun_name = Credo.Code.Module.def_name(ast)

        {
          ast,
          issues ++ [issue_for(issue_meta, meta[:line], fun_name, max_arity, arity)]
        }
      else
        {ast, issues}
      end
    end
  end

  defp traverse(ast, issues, _issue_meta, _max_arity, _ignore_defp) do
    {ast, issues}
  end

  def issue?(:defp, true, _, _), do: false
  def issue?(_, _, arity, max_arity) when arity > max_arity, do: true
  def issue?(_, _, _, _), do: false

  def issue_for(issue_meta, line_no, trigger, max_value, actual_value) do
    format_issue(
      issue_meta,
      message:
        "Function takes too many parameters (arity is #{actual_value}, max is #{max_value}).",
      trigger: trigger,
      line_no: line_no,
      severity: Severity.compute(actual_value, max_value)
    )
  end
end
