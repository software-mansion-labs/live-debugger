defmodule LiveDebugger.Services.CallbackTracer do
  @moduledoc """

  It starts a tracing session for the given monitored PID via `start_tracing_session/3`.
  When session is started sends traces to the recipient PID via message {:new_trace, trace}.
  It stores traces in an ETS table with id created by `CallbackTracer.ets_table_id/1`.

  The session should be stopped when monitored process is killed with `stop_tracing_session/1`.
  """

  require Logger

  alias LiveDebugger.Services.ModuleDiscovery
  alias LiveDebugger.Utils.Callbacks, as: CallbackUtils
  alias LiveDebugger.Structs.Trace

  @id_prefix "lvdbg"

  @type raw_trace :: {atom(), pid(), atom(), {atom(), atom(), [term()]}}

  @spec start_tracing_session(String.t(), pid(), pid()) ::
          {:ok, :dbg.session()} | {:error, term()}
  def start_tracing_session(socket_id, monitored_pid, recipient_pid) do
    with ets_table_id <- ets_table_id(socket_id),
         _table <- init_ets(ets_table_id),
         next_tuple_id <- next_tuple_id(ets_table_id),
         tracing_session_id <- tracing_session_id(monitored_pid),
         tracing_session <- :dbg.session_create(tracing_session_id) do
      :dbg.session(tracing_session, fn ->
        :dbg.tracer(
          :process,
          {fn msg, n -> trace_handler(msg, n, ets_table_id, recipient_pid) end, next_tuple_id}
        )

        :dbg.p(monitored_pid, :c)

        ModuleDiscovery.find_live_modules()
        |> CallbackUtils.tracing_callbacks()
        |> Enum.map(fn mfa -> :dbg.tp(mfa, []) end)
      end)

      {:ok, tracing_session}
    end
  rescue
    err ->
      Logger.error("Error while starting tracing session: #{inspect(err)}")
      {:error, err}
  end

  @spec stop_tracing_session(:dbg.session()) :: :ok
  def stop_tracing_session(session) do
    :dbg.session_destroy(session)
  end

  @spec ets_table_id(String.t()) :: :ets.table()
  def ets_table_id(socket_id), do: String.to_atom("#{@id_prefix}-#{socket_id}")

  @spec init_ets(atom()) :: :ets.table()
  defp init_ets(ets_table_id) do
    if :ets.whereis(ets_table_id) == :undefined do
      Logger.debug("Creating a new ETS table with id: #{ets_table_id}")
      :ets.new(ets_table_id, [:ordered_set, :public, :named_table])
    else
      ets_table_id
    end
  end

  # When new session is started we need to calculate the id of the next tuple that will be placed in given ETS table.
  #
  # When user is redirected to another LiveView in the same browser tab (PID changes) we start a new tracing session.
  # Since we still want to keep events from the previous session we need to calculate the next tuple id based on the last tuple id in the table.
  # If it wasn't calculated then events from the previous session would be overwritten since `dbg` would start from 0.
  @spec next_tuple_id(atom()) :: integer()
  defp next_tuple_id(ets_table_id) do
    case :ets.first(ets_table_id) do
      :"$end_of_table" -> 0
      last_id -> last_id - 1
    end
  end

  @spec tracing_session_id(pid()) :: atom()
  defp tracing_session_id(monitored_pid) do
    parsed_pid = monitored_pid |> :erlang.pid_to_list() |> to_string()
    String.to_atom("#{@id_prefix}-#{parsed_pid}")
  end

  @spec trace_handler(raw_trace(), integer(), :ets.table(), pid()) :: integer()
  defp trace_handler({_, pid, _, {module, function, args}}, n, ets_table_id, recipient_pid) do
    trace = Trace.new(module, function, args, pid)

    :ets.insert(ets_table_id, {n, trace})
    send(recipient_pid, {:new_trace, trace})

    n - 1
  end
end
