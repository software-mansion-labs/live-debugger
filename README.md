# LiveDebugger

## Local installation

Clone repository with:

```bash
git clone https://github.com/software-mansion-labs/live_debugger.git
```

Add `live_debugger` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:live_debugger, path: "../path/to/library"}
  ]
end
```

After that you can add LiveDebugger to your router:

```elixir
import LiveDebugger.Router

  scope "/" do
    pipe_through :browser

    live "/", CounterLive
    live_debugger "/dbg"
  end
```

## Contributing

For those planning to contribute to this project, you can run a dev version of the debugger with the following commands:

```bash
mix setup
mix dev
```

For now when you change something in `app.css` or in `app.js` you'll have rebuild assets with the following command:

```bash
mix assets.build
```
