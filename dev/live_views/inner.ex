defmodule LiveDebuggerDev.LiveViews.Inner do
  use DevWeb, :live_view

  alias LiveDebuggerDev.LiveComponents

  def mount(_params, session, socket) do
    socket = assign(socket, :info, session["info"])

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.box title="Inner [LiveView]" color="yellow">
      <div class="text-bold text-yellow-500">Info: <%= @info %></div>
      <.live_component id="very_long_name" module={LiveComponents.LiveComponentWithVeryVeryLongName} />
      <.live_component id="conditional" module={LiveComponents.Conditional}>
        <.live_component id="many_assigns" module={LiveComponents.ManyAssigns} />
      </.live_component>
    </.box>
    """
  end
end
