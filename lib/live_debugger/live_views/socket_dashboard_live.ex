defmodule LiveDebugger.LiveViews.SocketDashboardLive do
  use LiveDebuggerWeb, :live_view

  require Logger

  alias LiveDebugger.Services.LiveViewScraper
  alias LiveDebugger.Services.CallbackTracer

  @impl true
  def mount(%{"socket_id" => socket_id}, _session, socket) do
    socket
    |> assign(:socket_id, socket_id)
    |> assign(:tracing_session, nil)
    |> assign_async_debugged_pid()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.loading_variant :if={@debugged_pid.status == :loading} />
    <.not_found_component :if={@debugged_pid.status == :not_found} />
    <.error_component :if={@debugged_pid.status == :error} />
    <.container :if={@debugged_pid.status == :ok} max_width="full">
      <div>Monitored socket: <span class="text-blue-500">{@socket_id}</span></div>
      <div>Debugged PID: <span class="text-blue-500">{inspect(@debugged_pid.result)}</span></div>
      <.live_component
        id="event-list"
        module={LiveDebugger.LiveComponents.EventsList}
        debugged_node_id={@debugged_pid.result}
        socket_id={@socket_id}
      />
    </.container>
    """
  end

  @impl true
  def handle_async(:fetch_debugged_pid, {:ok, nil}, socket) do
    socket
    |> assign(:debugged_pid, %{status: :not_found, result: nil})
    |> noreply()
  end

  @impl true
  def handle_async(:fetch_debugged_pid, {:ok, fetched_pid}, socket) do
    Process.monitor(fetched_pid)

    {:ok, tracing_session} =
      CallbackTracer.start_tracing_session(socket.assigns.socket_id, fetched_pid, self())

    socket
    |> assign(:debugged_pid, %{status: :ok, result: fetched_pid})
    |> assign(:tracing_session, tracing_session)
    |> noreply()
  end

  @impl true
  def handle_async(:fetch_debugged_pid, {:exit, reason}, socket) do
    Logger.error(
      "LiveDebugger encountered unexpected error while fetching debugged pid: #{inspect(reason)}"
    )

    socket
    |> assign(:debugged_pid, %{status: :error, result: nil})
    |> noreply()
  end

  @impl true
  def handle_info({:DOWN, _, :process, _closed_pid, _}, socket) do
    CallbackTracer.stop_tracing_session(socket.assigns.tracing_session)

    socket
    |> assign_async_debugged_pid()
    |> noreply()
  end

  def handle_info({:new_trace, trace}, socket) do
    Logger.debug("Received a new trace: \n#{inspect(trace)}")

    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    CallbackTracer.stop_tracing_session(socket.assigns.tracing_session)
  end

  defp loading_variant(assigns) do
    ~H"""
    <div class="h-full flex items-center justify-center">
      <.spinner size="md" />
    </div>
    """
  end

  defp not_found_component(assigns) do
    ~H"""
    <div class="h-full flex flex-col items-center justify-center mx-8">
      <.icon name="hero-exclamation-circle" class="w-16 h-16" />
      <.h2 class="text-center">Debugger disconnected</.h2>
      <.h5 class="text-center">
        We couldn't find any LiveView associated with the given socket id
      </.h5>
      <span>You can close this window</span>
    </div>
    """
  end

  defp error_component(assigns) do
    ~H"""
    <div class="h-full flex flex-col items-center justify-center mx-8">
      <.icon name="hero-exclamation-circle" class="w-16 h-16" />
      <.h2 class="text-center">Unexpected error</.h2>
      <.h5 class="text-center">
        Debugger encountered unexpected error - check logs for more
      </.h5>
      <span>You can close this window</span>
    </div>
    """
  end

  defp assign_async_debugged_pid(socket) do
    socket_id = socket.assigns.socket_id

    socket
    |> assign(:debugged_pid, %{status: :loading})
    |> start_async(:fetch_debugged_pid, fn ->
      with nil <- fetch_pid_after(socket_id, 200),
           nil <- fetch_pid_after(socket_id, 800),
           nil <- fetch_pid_after(socket_id, 1000) do
        nil
      end
    end)
  end

  defp fetch_pid_after(socket_id, milliseconds) do
    Process.sleep(milliseconds)
    LiveViewScraper.pid_by_socket_id(socket_id)
  end
end
