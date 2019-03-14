defmodule Credo.Issue do
  @moduledoc """
  `Issue` structs represent all issues found during the code analysis.
  """

  @type t :: module

  defstruct check: nil,
            category: nil,
            priority: 0,
            severity: nil,
            message: nil,
            filename: nil,
            line_no: nil,
            column: nil,
            exit_status: 0,
            # optional: the String that triggered the check to fail
            trigger: nil,
            # optional: metadata filled in by the check
            meta: [],
            # optional: the name of the module, macro or
            #  function where the issue was found
            scope: nil
end
