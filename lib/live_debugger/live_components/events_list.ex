defmodule LiveDebugger.LiveComponents.EventsList do
  @moduledoc """
  This module provides a LiveComponent to display events.
  """

  use LiveDebuggerWeb, :live_component

  require Logger

  alias LiveDebugger.Components.Collapsible
  alias LiveDebugger.Services.TraceService
  alias LiveDebugger.Utils.TermParser
  alias LiveDebugger.Utils.Parsers

  @impl true
  def mount(socket) do
    socket
    |> assign(:hide_section?, false)
    |> ok()
  end

  @impl true
  def update(%{new_trace: trace}, socket) do
    socket
    |> stream_insert(:existing_traces, trace, at: 0)
    |> ok()
  end

  def update(assigns, socket) do
    socket
    |> assign(debugged_node_id: assigns.debugged_node_id)
    |> assign(id: assigns.id)
    |> assign(ets_table_id: TraceService.ets_table_id(assigns.socket_id))
    |> assign_async_existing_traces()
    |> ok()
  end

  attr(:id, :string, required: true)
  attr(:debugged_node_id, :map, required: true)
  attr(:socket_id, :string, required: true)
  attr(:hide_section?, :boolean, required: true)

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <Collapsible.section
        title="Events"
        id="events"
        class="h-full md:overflow-y-auto"
        myself={@myself}
        hide?={@hide_section?}
      >
        <:right_panel>
          <.button color="primary" phx-click="clear-events" phx-target={@myself}>
            Clear
          </.button>
        </:right_panel>
        <div class="w-full">
          <div id={"#{assigns.id}-stream"} phx-update="stream">
            <div id={"#{assigns.id}-stream-empty"} class="only:block hidden text-gray-700">
              <div :if={@existing_traces_status == :ok}>
                No events have been recorded yet.
              </div>
              <div
                :if={@existing_traces_status == :loading}
                class="w-full flex items-center justify-center"
              >
                <.spinner size="sm" />
              </div>
              <.alert
                :if={@existing_traces_status == :error}
                variant="danger"
                with_icon
                heading="Error fetching historical events"
              >
                The new events still will be displayed as they come. Check logs for more
              </.alert>
            </div>
            <%= for {dom_id, trace} <- @streams.existing_traces do %>
              <.trace id={dom_id} trace={trace} />
            <% end %>
          </div>
        </div>
      </Collapsible.section>
    </div>
    """
  end

  @impl true
  def handle_async(:fetch_existing_traces, {:ok, trace_list}, socket) do
    socket
    |> assign(existing_traces_status: :ok)
    |> stream(:existing_traces, trace_list)
    |> noreply()
  end

  def handle_async(:fetch_existing_traces, {:exit, reason}, socket) do
    Logger.error(
      "LiveDebugger encountered unexpected error while fetching existing traces: #{inspect(reason)}"
    )

    socket
    |> assign(existing_traces_status: :error)
    |> noreply()
  end

  @impl true
  def handle_event("toggle-visibility", _, socket) do
    socket
    |> assign(hide_section?: not socket.assigns.hide_section?)
    |> noreply()
  end

  def handle_event("clear-events", _, socket) do
    ets_table_id = socket.assigns.ets_table_id
    node_id = socket.assigns.debugged_node_id

    TraceService.clear_traces(ets_table_id, node_id)

    socket
    |> stream(:existing_traces, [], reset: true)
    |> noreply()
  end

  attr(:id, :string, required: true)
  attr(:trace, :map, required: true, doc: "The Trace struct to render")

  defp trace(assigns) do
    ~H"""
    <Collapsible.collapsible id={@id} icon="hero-chevron-down-micro" chevron_class="text-primary">
      <:label>
        <div class="w-full flex justify-between">
          <.tooltip
            id={"trace_" <> @id}
            position="top"
            content={"#{@trace.module}.#{@trace.function}/#{@trace.arity}"}
          >
            <p class="text-primary font-medium"><%= @trace.function %>/<%= @trace.arity %></p>
          </.tooltip>
          <p class="w-32"><%= Parsers.parse_timestamp(@trace.timestamp) %></p>
        </div>
      </:label>

      <div class="relative flex flex-col gap-4 overflow-x-auto h-[30vh] max-h-max overflow-y-auto border-2 border-gray-200 p-2 rounded-lg text-gray-600">
        <.fullscreen_wrapper id={@id <> "-fullscreen"} class="absolute top-0 right-0">
          <div class="w-full flex flex-col items-start justify-center">
            <%= for {args, index} <- Enum.with_index(@trace.args) do %>
              <.live_component
                id={@id <> "-#{index}-fullscreen"}
                module={LiveDebugger.LiveComponents.ElixirDisplay}
                node={TermParser.term_to_display_tree(args)}
                level={1}
              />
            <% end %>
          </div>
        </.fullscreen_wrapper>
        <%= for {args, index} <- Enum.with_index(@trace.args) do %>
          <.live_component
            id={@id <> "-#{index}"}
            module={LiveDebugger.LiveComponents.ElixirDisplay}
            node={TermParser.term_to_display_tree(args)}
            level={1}
          />
        <% end %>
      </div>
    </Collapsible.collapsible>
    """
  end

  defp assign_async_existing_traces(socket) do
    ets_table_id = socket.assigns.ets_table_id
    node_id = socket.assigns.debugged_node_id

    socket
    |> assign(:existing_traces_status, :loading)
    |> stream(:existing_traces, [], reset: true)
    |> start_async(:fetch_existing_traces, fn ->
      TraceService.existing_traces(ets_table_id, node_id)
    end)
  end
end
