# SPDX-License-Identifier: Apache-2.0
defmodule Tools.Tracer do
  defmacro deft(head, body) do
    {fun_name, args_ast} = name_and_args(head)

    decorated = decorate_args(args_ast)
    arg_names = decorated |> Enum.map(fn {x, _} -> x end)
    decorated_args = decorated |> Enum.map(fn {_, x} -> x end)

    head = Macro.postwalk(head,
      fn
        ({fun_ast, context, old_args}) when (
          fun_ast == fun_name and old_args == args_ast
        ) ->
          {fun_ast, context, decorated_args}
        (other) -> other
      end)

    quote do
      def unquote(head) do
        file = __ENV__.file
        line = __ENV__.line
        module = __ENV__.module

        function_name = unquote(fun_name)
        passed_args = unquote(arg_names) |> Enum.map(&inspect/1) |> Enum.join(",")

        result = unquote(body[:do])

        loc = "#{file}(line #{line})"
        call = "#{module}.#{function_name}(#{passed_args}) = #{inspect result}"
        IO.puts "#{loc} #{call}"

        result
      end
    end
  end

  defp name_and_args({:when, _, [short_head | _]}) do
    name_and_args(short_head)
  end

  defp name_and_args(short_head) do
    Macro.decompose_call(short_head)
  end

  defp decorate_args([]), do: {[],[]}
  defp decorate_args(args_ast) do
    for {arg_ast, index} <- Enum.with_index(args_ast) do
      # dynamically generate quoted identifier
      arg_name = Macro.var(:"arg#{index}", __MODULE__)

      # generate AST for patternX = argX
      full_arg = quote do
        unquote(arg_ast) = unquote(arg_name)
      end

      {arg_name, full_arg}
    end
  end
end

# SPDX-License-Identifier: Apache-2.0
