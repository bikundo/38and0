defmodule InvinciblesWeb.DirectoryLive do
  use InvinciblesWeb, :live_view
  alias Invincibles.Game
  alias Invincibles.Repo
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"club_slug" => club_slug, "season_slug" => season_slug}, _url, socket) do
    case get_club_by_slug(club_slug) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Club not found.")
         |> redirect(to: ~p"/squads")}

      club ->
        appearances = Game.list_appearances_for_club_and_season(club.id, season_slug)

        if appearances == [] do
          {:noreply,
           socket
           |> put_flash(
             :error,
             "No squad data available for #{club.name} during the #{season_slug} season."
           )
           |> redirect(to: ~p"/squads/#{club_slug}")}
        else
          # Calculate FAQ Schema details
          highest_rated = Enum.max_by(appearances, & &1.ovr)
          highest_rated_player = highest_rated.player.display_name
          highest_rated_ovr = highest_rated.ovr

          schema_map = %{
            "@context" => "https://schema.org",
            "@type" => "FAQPage",
            "mainEntity" => [
              %{
                "@type" => "Question",
                "name" =>
                  "Who is the highest rated player in the #{club.name} #{season_slug} squad?",
                "acceptedAnswer" => %{
                  "@type" => "Answer",
                  "text" =>
                    "The highest rated player in the #{club.name} #{season_slug} squad is #{highest_rated_player} with an overall rating (OVR) of #{highest_rated_ovr}."
                }
              },
              %{
                "@type" => "Question",
                "name" => "Can I draft and play with the #{club.name} #{season_slug} team?",
                "acceptedAnswer" => %{
                  "@type" => "Answer",
                  "text" =>
                    "Yes! You can draft players from the #{club.name} #{season_slug} team and simulate a 38-game season using the retro draft simulator."
                }
              }
            ]
          }

          schema_json = Jason.encode!(schema_map)

          socket =
            socket
            |> assign(:live_action, :squad)
            |> assign(:club, club)
            |> assign(:season, season_slug)
            |> assign(:appearances, appearances)
            |> assign(:highest_rated_player, highest_rated_player)
            |> assign(:highest_rated_ovr, highest_rated_ovr)
            |> assign(:schema_json, schema_json)
            |> assign(:page_title, "#{club.name} #{season_slug} Retro Squad & Ratings")
            |> assign(
              :meta_description,
              "View the complete squad ratings, players, and stats for #{club.name} during the #{season_slug} Premier League season. Play retro squad draft simulator."
            )
            |> assign(:current_path, "/squads/#{club_slug}/#{season_slug}")

          {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_params(%{"club_slug" => club_slug}, _url, socket) do
    case get_club_by_slug(club_slug) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Club not found.")
         |> redirect(to: ~p"/squads")}

      club ->
        seasons = Game.list_seasons_for_club(club.id)

        schema_map = %{
          "@context" => "https://schema.org",
          "@type" => "ItemList",
          "name" => "#{club.name} Historical Seasons",
          "numberOfItems" => length(seasons),
          "itemListElement" =>
            Enum.with_index(seasons, 1)
            |> Enum.map(fn {season, idx} ->
              %{
                "@type" => "ListItem",
                "position" => idx,
                "url" => "https://invincibles.website/squads/#{club_slug}/#{season}",
                "name" => "#{club.name} #{season} Season Squad"
              }
            end)
        }

        schema_json = Jason.encode!(schema_map)

        socket =
          socket
          |> assign(:live_action, :club)
          |> assign(:club, club)
          |> assign(:seasons, seasons)
          |> assign(:schema_json, schema_json)
          |> assign(:page_title, "#{club.name} History & Retro Squads")
          |> assign(
            :meta_description,
            "Explore the historical Premier League squads and ratings for #{club.name} since 1992. Draft retro teams in the simulator."
          )
          |> assign(:current_path, "/squads/#{club_slug}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    clubs = Game.list_all_clubs()

    schema_map = %{
      "@context" => "https://schema.org",
      "@type" => "ItemList",
      "name" => "Premier League Retro Squads Directory",
      "numberOfItems" => length(clubs),
      "itemListElement" =>
        Enum.with_index(clubs, 1)
        |> Enum.map(fn {club, idx} ->
          %{
            "@type" => "ListItem",
            "position" => idx,
            "url" => "https://invincibles.website/squads/#{slugify(club.name)}",
            "name" => club.name
          }
        end)
    }

    schema_json = Jason.encode!(schema_map)

    socket =
      socket
      |> assign(:live_action, :index)
      |> assign(:clubs, clubs)
      |> assign(:schema_json, schema_json)
      |> assign(:page_title, "Historical Premier League Teams & Squads")
      |> assign(
        :meta_description,
        "Browse the complete directory of retro Premier League squads since 1992. View players ratings, stats and draft teams."
      )
      |> assign(:current_path, "/squads")

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active_tab={:directory}>
      <div class="min-h-screen bg-[#f2f0eb] text-[rgba(0,0,0,0.87)] font-sans flex flex-col pb-16">
        <!-- Schema JSON-LD Injection -->
        <script type="application/ld+json">
          <%= {:safe, @schema_json} %>
        </script>

        <main class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 mt-8 w-full flex-1 flex flex-col gap-8">
          <%= cond do %>
            <% @live_action == :index -> %>
              <!-- INDEX VIEW: List of Clubs -->
              <div class="card-starbucks p-6 md:p-8 flex flex-col gap-6">
                <div>
                  <h1 class="text-3xl font-black tracking-tight text-[#006241]">
                    Premier League Retro Squads
                  </h1>
                  <p class="text-sm text-[rgba(0,0,0,0.58)] mt-2 leading-relaxed">
                    Select a club below to explore their historical Premier League squads, player ratings, and stats since 1992. Start a retro draft with your favorite squad.
                  </p>
                </div>

                <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4 mt-2">
                  <%= for club <- @clubs do %>
                    <.link
                      navigate={~p"/squads/#{slugify(club.name)}"}
                      class="flex items-center gap-4 p-4 border border-[rgba(0,0,0,0.06)] rounded-xl hover:border-[#00754A] hover:bg-white hover:shadow-md transition-all duration-200 group"
                    >
                      <div
                        class="w-12 h-12 rounded-full flex items-center justify-center text-white font-extrabold text-sm shadow-sm"
                        style={"background-color: #{club.primary_color}"}
                      >
                        {club.short_name}
                      </div>
                      <div>
                        <h2 class="font-bold text-base text-[rgba(0,0,0,0.87)] group-hover:text-[#00754A] transition-colors">
                          {club.name}
                        </h2>
                        <span class="text-[11px] text-[rgba(0,0,0,0.4)] font-medium uppercase tracking-wider">
                          View Historical Squads
                        </span>
                      </div>
                    </.link>
                  <% end %>
                </div>
              </div>
            <% @live_action == :club -> %>
              <!-- CLUB VIEW: List of Seasons for a Club -->
              <div class="flex flex-col gap-6">
                <div class="flex items-center gap-3">
                  <.link
                    navigate={~p"/squads"}
                    class="p-2 bg-white border border-[rgba(0,0,0,0.08)] rounded-full hover:border-[#00754A] hover:bg-[#00754A] hover:text-white transition-all shadow-sm"
                  >
                    <.icon name="hero-arrow-left" class="w-4 h-4" />
                  </.link>
                  <span class="text-xs font-bold uppercase tracking-wider text-[rgba(0,0,0,0.4)]">
                    Back to clubs directory
                  </span>
                </div>

                <div class="card-starbucks p-6 md:p-8 flex flex-col gap-6">
                  <div class="flex items-center gap-4 border-b border-[rgba(0,0,0,0.08)] pb-6">
                    <div
                      class="w-16 h-16 rounded-2xl flex items-center justify-center text-white font-black text-xl shadow"
                      style={"background-color: #{@club.primary_color}"}
                    >
                      {@club.short_name}
                    </div>
                    <div>
                      <h1 class="text-3xl font-black tracking-tight text-[#006241]">
                        {@club.name}
                      </h1>
                      <p class="text-xs text-[rgba(0,0,0,0.58)] mt-1">
                        Select a Premier League campaign to view retro squad ratings.
                      </p>
                    </div>
                  </div>

                  <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                    <%= for season <- @seasons do %>
                      <.link
                        navigate={~p"/squads/#{slugify(@club.name)}/#{season}"}
                        class="p-5 border border-[rgba(0,0,0,0.06)] rounded-xl hover:border-[#00754A] hover:bg-white hover:shadow-md transition-all duration-200 group flex flex-col gap-2"
                      >
                        <span class="text-lg font-black text-[#006241]">
                          {season}
                        </span>
                        <span class="text-xs text-[rgba(0,0,0,0.5)] font-semibold uppercase tracking-wider">
                          Squad & Ratings
                        </span>
                      </.link>
                    <% end %>
                  </div>
                </div>
              </div>
            <% @live_action == :squad -> %>
              <!-- SQUAD VIEW: Squad Sheet & Details -->
              <div class="flex flex-col gap-6">
                <div class="flex items-center gap-3">
                  <.link
                    navigate={~p"/squads/#{slugify(@club.name)}"}
                    class="p-2 bg-white border border-[rgba(0,0,0,0.08)] rounded-full hover:border-[#00754A] hover:bg-[#00754A] hover:text-white transition-all shadow-sm"
                  >
                    <.icon name="hero-arrow-left" class="w-4 h-4" />
                  </.link>
                  <span class="text-xs font-bold uppercase tracking-wider text-[rgba(0,0,0,0.4)]">
                    Back to {@club.name} seasons
                  </span>
                </div>
                
    <!-- Play/Draft CTA Banner -->
                <div class="bg-gradient-to-r from-[#006241] to-[#00754A] text-white rounded-2xl p-6 md:p-8 flex flex-col md:flex-row md:items-center justify-between gap-6 shadow-lg">
                  <div class="flex flex-col gap-1.5 max-w-xl">
                    <span class="text-[10px] font-bold uppercase tracking-[1.5px] text-white/75">
                      Retro Draft Simulator
                    </span>
                    <h2 class="text-2xl md:text-3xl font-black tracking-tight leading-tight">
                      Draft with {@club.name} {@season}
                    </h2>
                    <p class="text-xs md:text-sm text-white/80 leading-relaxed font-medium">
                      Start your 38-game season draft campaign using the squad sheets from the legendary {@club.name} {@season} team! Skip the random spin.
                    </p>
                  </div>
                  <.link
                    navigate={~p"/?club_id=#{@club.id}&season=#{@season}"}
                    class="btn-starbucks btn-starbucks-white whitespace-nowrap self-start md:self-auto py-3.5 px-6 font-bold shadow hover:scale-105 transition-all text-xs tracking-wider uppercase text-[#006241]"
                  >
                    Draft With This Team
                  </.link>
                </div>
                
    <!-- Squad Breakdown -->
                <div class="card-starbucks p-6 md:p-8 flex flex-col gap-8">
                  <div class="flex flex-col sm:flex-row sm:items-center justify-between border-b border-[rgba(0,0,0,0.08)] pb-6 gap-4">
                    <div class="flex items-center gap-4">
                      <div
                        class="w-14 h-14 rounded-xl flex items-center justify-center text-white font-black text-lg shadow"
                        style={"background-color: #{@club.primary_color}"}
                      >
                        {@club.short_name}
                      </div>
                      <div>
                        <h1 class="text-2xl font-black tracking-tight text-[#006241]">
                          {@club.name} {@season} Squad
                        </h1>
                        <p class="text-xs text-[rgba(0,0,0,0.58)] mt-0.5">
                          List of all registered players and retro ratings.
                        </p>
                      </div>
                    </div>
                    <div class="flex items-center gap-4 bg-[#edebe9] px-4 py-2.5 rounded-xl border border-[rgba(0,0,0,0.04)]">
                      <div class="flex flex-col">
                        <span class="text-[9px] font-bold text-[rgba(0,0,0,0.4)] uppercase tracking-wider">
                          Squad Size
                        </span>
                        <span class="text-sm font-extrabold text-[rgba(0,0,0,0.8)]">
                          {length(@appearances)} Players
                        </span>
                      </div>
                      <div class="w-px h-6 bg-[rgba(0,0,0,0.1)]"></div>
                      <div class="flex flex-col">
                        <span class="text-[9px] font-bold text-[rgba(0,0,0,0.4)] uppercase tracking-wider">
                          Highest OVR
                        </span>
                        <span class="text-sm font-extrabold text-[#00754A] flex items-center gap-1">
                          {@highest_rated_ovr}
                          <span class="text-[10px] font-normal text-[rgba(0,0,0,0.5)]">
                            ({truncate_name(@highest_rated_player)})
                          </span>
                        </span>
                      </div>
                    </div>
                  </div>
                  
    <!-- Group appearances by position category -->
                  <% grouped_appearances = Enum.group_by(@appearances, & &1.player.primary_position) %>

                  <%= for {pos_label, pos_key} <- [
                        {"Goalkeepers", "GK"},
                        {"Defenders", "DF"},
                        {"Midfielders", "MF"},
                        {"Forwards", "FW"}
                      ] do %>
                    <% apps = Map.get(grouped_appearances, pos_key, []) %>
                    <%= if apps != [] do %>
                      <div class="flex flex-col gap-4">
                        <h3 class="text-xs font-black uppercase tracking-wider text-[rgba(0,0,0,0.4)] border-b border-[rgba(0,0,0,0.04)] pb-2">
                          {pos_label}
                        </h3>

                        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                          <%= for app <- apps do %>
                            <div class="border border-[rgba(0,0,0,0.06)] rounded-2xl bg-[#f7f7f5] hover:bg-white hover:border-[#00754A] hover:shadow-md transition-all duration-200 p-4 flex flex-col justify-between gap-3">
                              <div class="flex justify-between items-start">
                                <div class="flex flex-col">
                                  <span class="font-extrabold text-sm text-[rgba(0,0,0,0.85)] leading-tight">
                                    {app.player.display_name}
                                  </span>
                                  <span class="text-[10px] font-bold text-[rgba(0,0,0,0.4)] uppercase mt-0.5 tracking-wide">
                                    {app.player.primary_position} · {app.season}
                                  </span>
                                </div>
                                <span class="inline-flex items-center justify-center w-8 h-8 rounded-full bg-[#edebe9] text-[rgba(0,0,0,0.87)] font-black text-sm shadow-sm border border-[rgba(0,0,0,0.04)]">
                                  {app.ovr}
                                </span>
                              </div>
                              
    <!-- Player stats grid -->
                              <div class="grid grid-cols-3 gap-x-2 gap-y-1.5 bg-white border border-[rgba(0,0,0,0.04)] rounded-xl p-2.5 text-center">
                                <%= if app.player.primary_position == "GK" do %>
                                  <!-- GK stats -->
                                  <%= for {stat_label, stat_key} <- [
                                        {"DIV", "div"},
                                        {"HAN", "han"},
                                        {"KIC", "kic"},
                                        {"REF", "ref"},
                                        {"SPD", "spd"},
                                        {"POS", "pos"}
                                      ] do %>
                                    <div class="flex flex-col">
                                      <span class="text-[9px] font-bold text-[rgba(0,0,0,0.4)] uppercase tracking-wider">
                                        {stat_label}
                                      </span>
                                      <span class="text-xs font-extrabold text-[rgba(0,0,0,0.8)]">
                                        {Map.get(app.stats, stat_key) ||
                                          Map.get(app.stats, String.to_atom(stat_key)) || "-"}
                                      </span>
                                    </div>
                                  <% end %>
                                <% else %>
                                  <!-- Outfield stats -->
                                  <%= for {stat_label, stat_key} <- [
                                        {"PAC", "pac"},
                                        {"SHO", "sho"},
                                        {"PAS", "pas"},
                                        {"DRI", "dri"},
                                        {"DEF", "def"},
                                        {"PHY", "phy"}
                                      ] do %>
                                    <div class="flex flex-col">
                                      <span class="text-[9px] font-bold text-[rgba(0,0,0,0.4)] uppercase tracking-wider">
                                        {stat_label}
                                      </span>
                                      <span class="text-xs font-extrabold text-[rgba(0,0,0,0.8)]">
                                        {Map.get(app.stats, stat_key) ||
                                          Map.get(app.stats, String.to_atom(stat_key)) || "-"}
                                      </span>
                                    </div>
                                  <% end %>
                                <% end %>
                              </div>
                            </div>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </div>
          <% end %>
        </main>
      </div>
    </Layouts.app>
    """
  end

  # Helper to query using a case-insensitive slug comparison
  defp get_club_by_slug(slug) do
    query =
      from(c in Game.Club, where: fragment("LOWER(REPLACE(?, ' ', '-')) = ?", c.name, ^slug))

    Repo.one(query)
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(" ", "-")
  end

  defp truncate_name(name) do
    case String.split(name, " ") do
      [single] -> single
      parts -> List.last(parts)
    end
  end
end
