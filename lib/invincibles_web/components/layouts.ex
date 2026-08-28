defmodule InvinciblesWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use InvinciblesWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :record, :map, default: nil, doc: "the current season record"
  attr :active_tab, :atom, default: :draft
  attr :step, :atom, default: nil

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="bg-white border-b border-[rgba(0,0,0,0.08)] sticky top-0 z-50 shadow-[0_1px_3px_rgba(0,0,0,0.1),_0_2px_2px_rgba(0,0,0,0.06),_0_0_2px_rgba(0,0,0,0.07)]">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 transition-all duration-200">
        <div class="h-16 sm:h-[72px] md:h-[83px] lg:h-[99px] flex items-center justify-between">
          <div class="flex items-center gap-6 md:gap-10">
            <a href="/" class="flex items-center gap-3">
              <span class="text-lg md:text-xl font-bold tracking-tighter text-[#006241]">
                INVINCIBLES
              </span>
            </a>

            <nav class="hidden md:flex items-center gap-6">
              <.link
                navigate={~p"/"}
                class={[
                  "text-xs font-bold uppercase tracking-[0.1em] py-4",
                  if(
                    @active_tab != :leaderboard and
                      @step not in [:simulating, :game_over, :hall_of_fame],
                    do: "text-[#006241] border-b-4 border-[#006241] mt-1",
                    else: "text-[rgba(0,0,0,0.87)] hover:text-[#00754A] transition-colors"
                  )
                ]}
              >
                Draft
              </.link>
              <.link
                navigate={~p"/"}
                class={[
                  "text-xs font-bold uppercase tracking-[0.1em] py-4",
                  if(
                    @active_tab != :leaderboard and @step in [:simulating, :game_over, :hall_of_fame],
                    do: "text-[#006241] border-b-4 border-[#006241] mt-1",
                    else: "text-[rgba(0,0,0,0.87)] hover:text-[#00754A] transition-colors"
                  )
                ]}
              >
                Simulation
              </.link>
              <.link
                navigate={~p"/?tab=leaderboard"}
                class={[
                  "text-xs font-bold uppercase tracking-[0.1em] py-4",
                  if(@active_tab == :leaderboard,
                    do: "text-[#006241] border-b-4 border-[#006241] mt-1",
                    else: "text-[rgba(0,0,0,0.87)] hover:text-[#00754A] transition-colors"
                  )
                ]}
              >
                Leaderboard
              </.link>
            </nav>
          </div>

          <div class="flex items-center gap-3">
            <%= if @record do %>
              <div class="flex flex-col text-right">
                <span class="text-[9px] font-bold text-[rgba(0,0,0,0.58)] uppercase tracking-[0.6px] leading-none">
                  Record
                </span>
                <span class="text-sm font-bold tracking-wide text-[rgba(0,0,0,0.87)] mt-1">
                  {@record.wins}W - {@record.draws}D - {@record.losses}L
                </span>
              </div>
              <%= if @record.week > 0 do %>
                <span class="bg-[#00754A] text-white text-[10px] font-bold uppercase px-2.5 py-1 rounded-full ml-1">
                  GW {@record.week}
                </span>
              <% end %>
            <% end %>

            <a
              href="https://github.com/bikundo/38and0"
              target="_blank"
              rel="noopener noreferrer"
              class="p-2 text-[rgba(0,0,0,0.6)] hover:text-[#00754A] transition-colors"
              title="GitHub Repository"
            >
              <svg class="w-5 h-5 fill-current" viewBox="0 0 24 24" aria-hidden="true">
                <path
                  fill-rule="evenodd"
                  clip-rule="evenodd"
                  d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.53 1.032 1.53 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"
                />
              </svg>
            </a>
          </div>
        </div>

        <nav class="flex md:hidden items-center justify-around pb-3 border-t border-[rgba(0,0,0,0.04)] pt-2 gap-4">
          <.link
            navigate={~p"/"}
            class={[
              "text-xs font-bold uppercase tracking-[0.1em] py-2",
              if(
                @active_tab != :leaderboard and
                  @step not in [:simulating, :game_over, :hall_of_fame],
                do: "text-[#006241] border-b-2 border-[#006241] mt-0.5",
                else: "text-[rgba(0,0,0,0.87)] hover:text-[#00754A] transition-colors"
              )
            ]}
          >
            Draft
          </.link>
          <.link
            navigate={~p"/"}
            class={[
              "text-xs font-bold uppercase tracking-[0.1em] py-2",
              if(@active_tab != :leaderboard and @step in [:simulating, :game_over, :hall_of_fame],
                do: "text-[#006241] border-b-2 border-[#006241] mt-0.5",
                else: "text-[rgba(0,0,0,0.87)] hover:text-[#00754A] transition-colors"
              )
            ]}
          >
            Simulation
          </.link>
          <.link
            navigate={~p"/?tab=leaderboard"}
            class={[
              "text-xs font-bold uppercase tracking-[0.1em] py-2",
              if(@active_tab == :leaderboard,
                do: "text-[#006241] border-b-2 border-[#006241] mt-0.5",
                else: "text-[rgba(0,0,0,0.87)] hover:text-[#00754A] transition-colors"
              )
            ]}
          >
            Leaderboard
          </.link>
        </nav>
      </div>
    </header>

    <main class="w-full">
      {render_slot(@inner_block)}
    </main>

    <footer class="bg-white border-t border-[rgba(0,0,0,0.08)] py-8 text-center text-[11px] text-[rgba(0,0,0,0.4)] font-bold tracking-wider uppercase">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex flex-col sm:flex-row items-center justify-between gap-4">
        <div>
          &copy; {Date.utc_today().year} Invincibles · Premier League Retro Draft
        </div>
        <div class="flex items-center gap-6">
          <.link navigate={~p"/"} class="hover:text-[#00754A] transition-colors">Draft</.link>
          <.link navigate={~p"/?tab=leaderboard"} class="hover:text-[#00754A] transition-colors">
            Leaderboard
          </.link>
          <.link navigate={~p"/squads"} class="hover:text-[#00754A] transition-colors">
            Clubs Directory
          </.link>
          <.link navigate={~p"/sitemap.xml"} class="hover:text-[#00754A] transition-colors">
            Sitemap
          </.link>
          <a
            href="https://github.com/bikundo/38and0"
            target="_blank"
            rel="noopener noreferrer"
            class="hover:text-[#00754A] transition-colors"
          >
            GitHub
          </a>
        </div>
      </div>
    </footer>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
