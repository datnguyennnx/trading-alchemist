defmodule CentralWeb.ChangelogHTML do
  use CentralWeb, :html
  import CentralWeb.Components.FlickeringGrid

  embed_templates "/*"

  attr :title, :string, required: true
  attr :entries, :list, required: true

  @spec changelog(map()) :: Phoenix.LiveView.Rendered.t()
  def changelog(assigns) do
    ~H"""
    <div class="min-h-screen bg-white relative text-black">
      <div class="absolute inset-0 z-0 overflow-hidden">
        <.flickering_grid
          id="changelog-background"
          square_size={6}
          grid_gap={6}
          flicker_chance={0.5}
          color="rgb(0, 0, 0)"
          max_opacity={0.05}
        />
      </div>

      <div class="max-w-3xl mx-auto py-12 px-6 relative z-10 ">
        <div class="mb-10">
          <h1 class="text-3xl font-extrabold">{@title}</h1>
          <h2 class="mt-2 font-bold">New updates and improvements</h2>
        </div>

        <div class="relative">
          <!-- Timeline track in center of dots -->
          <div class="absolute left-4 top-0 bottom-0 w-0.5 bg-neutral-300 -translate-x-1/2"></div>

          <ul class="space-y-16">
            <%= for entry <- @entries do %>
              <li id={"version-#{entry.version}"} class="relative pl-12">
                <!-- Version dot -->
                <div class="absolute left-4 -translate-x-1/2">
                  <div class="w-3 h-3 bg-black rounded-full z-10 relative"></div>
                </div>
                
    <!-- Version content -->
                <div>
                  <!-- Version header -->
                  <div class="flex items-baseline">
                    <div class="font-mono bg-neutral-200 text-sm px-2 py-0.5 rounded">
                      {entry.version}
                    </div>
                    <div class="text-neutral-700 text-sm ml-3">{entry.date}</div>
                  </div>

                  <h2 class="text-2xl font-bold mt-2">{entry.title}</h2>
                  <p class="text-neutral-700 mt-2 mb-8">{entry.description}</p>

                  <%= if length(entry.features) > 0 do %>
                    <div class="mb-8">
                      <h3 class="text-lg font-semibold mb-4">Key Features</h3>

                      <ul class="space-y-4 list-disc pl-5">
                        <%= for feature <- entry.features do %>
                          <li>
                            <h4 class="font-medium mb-1">{feature.title}</h4>
                            <p class="text-neutral-700">{feature.description}</p>
                          </li>
                        <% end %>
                      </ul>
                    </div>
                  <% end %>

                  <div>
                    <h3 class="text-lg font-semibold mb-4">All Changes</h3>

                    <ul class="space-y-3 list-disc pl-5">
                      <%= for change <- entry.changes do %>
                        <li class="text-neutral-700">
                          <div class="flex items-baseline">
                            {change.description}
                          </div>
                        </li>
                      <% end %>
                    </ul>
                  </div>
                </div>
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </div>
    """
  end
end
