defmodule LiveDebugger.LiveComponents.DetailView do
  @moduledoc """
  This module is responsible for rendering the detail view of the TreeNode.
  """

  use LiveDebuggerWeb, :live_component

  alias LiveDebugger.Structs.TreeNode
  alias Phoenix.LiveView.AsyncResult
  alias LiveDebugger.Services.ChannelService
  alias LiveDebugger.Utils.TermParser
  alias LiveDebugger.Components.ElixirDisplay

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(%{
      node_id: assigns.node_id || assigns.pid,
      pid: assigns.pid,
      socket_id: assigns.socket_id
    })
    |> assign_async_node_with_type()
    |> ok()
  end

  attr(:node_id, :any, required: true)
  attr(:pid, :any, required: true)
  attr(:socket_id, :string, required: true)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col w-full h-screen max-h-screen p-2 overflow-x-hidden overflow-y-auto lg:overflow-y-hidden">
      <.async_result :let={node} assign={@node}>
        <:loading>
          <div class="w-full flex items-center justify-center">
            <.spinner size="md" />
          </div>
        </:loading>
        <:failed :let={reason}>
          <.alert variant="danger">
            Failed to fetch node details: <%= inspect(reason) %>
          </.alert>
        </:failed>
        <div class="grid grid-cols-1 lg:grid-cols-2 lg:h-full">
          <div class="flex flex-col max lg:border-r-2 border-primary lg:overflow-y-hidden">
            <.info_card node={node} node_type={@node_type.result} />
            <.assigns_card assigns={node.assigns} />
          </div>
          <.live_component
            id="trace-list"
            module={LiveDebugger.LiveComponents.TracesList}
            debugged_node_id={@node_id}
            socket_id={@socket_id}
          />
        </div>
      </.async_result>
    </div>
    """
  end

  attr(:node, :any, required: true)
  attr(:node_type, :atom, required: true)

  defp info_card(assigns) do
    ~H"""
    <.collapsible_section id="info" title={title(@node_type)} class="border-b-2 border-primary">
      <div class=" flex flex-col gap-1">
        <.info_row name={id_type(@node_type)} value={TreeNode.display_id(@node)} />
        <.info_row name="Module" value={inspect(@node.module)} />
      </div>
    </.collapsible_section>
    """
  end

  attr(:name, :string, required: true)
  attr(:value, :any, required: true)

  defp info_row(assigns) do
    ~H"""
    <div class="flex gap-1 overflow-x-hidden">
      <div class="font-bold w-20 text-primary">
        <%= @name %>
      </div>
      <div class="font-semibold break-all">
        <%= @value %>
      </div>
    </div>
    """
  end

  defp title(:live_component), do: "LiveComponent"
  defp title(:live_view), do: "LiveView"

  defp id_type(:live_component), do: "CID"
  defp id_type(:live_view), do: "PID"

  attr(:assigns, :list, required: true)

  defp assigns_card(assigns) do
    ~H"""
    <.collapsible_section
      id="assigns"
      class="border-b-2 lg:border-b-0 border-primary h-max overflow-y-hidden"
      title="Assigns"
    >
      <div class="relative w-full max-h-full border-2 border-gray-200 rounded-lg p-4 overflow-y-auto text-gray-600">
        <.fullscreen_wrapper id="assigns-display-fullscreen" class="absolute top-0 right-0">
          <ElixirDisplay.term
            id="assigns-display-fullscreen"
            node={TermParser.term_to_display_tree(@assigns)}
            level={1}
          />
        </.fullscreen_wrapper>
        <ElixirDisplay.term
          id="assigns-display"
          node={TermParser.term_to_display_tree(@assigns)}
          level={1}
        />
      </div>
    </.collapsible_section>
    """
  end

  defp assign_async_node_with_type(%{assigns: %{node_id: node_id, pid: pid}} = socket)
       when not is_nil(node_id) do
    assign_async(socket, [:node, :node_type], fn ->
      with {:ok, channel_state} <- ChannelService.state(pid),
           {:ok, node} <- ChannelService.get_node(channel_state, node_id),
           true <- not is_nil(node) do
        {:ok, %{node: node, node_type: TreeNode.type(node)}}
      else
        false -> {:error, :node_deleted}
        err -> err
      end
    end)
  end

  defp assign_async_node_with_type(socket) do
    socket
    |> assign(:node, AsyncResult.failed(%AsyncResult{}, :no_node_id))
    |> assign(:node_type, AsyncResult.failed(%AsyncResult{}, :no_node_id))
  end
end
