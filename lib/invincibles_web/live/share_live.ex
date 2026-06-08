defmodule InvinciblesWeb.ShareLive do
  use InvinciblesWeb, :live_view
  alias Invincibles.Game
  alias InvinciblesWeb.GameLive

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Game.get_share(id) do
      {:ok, share} ->
        wins = Map.get(share.season_record, "wins") || Map.get(share.season_record, :wins) || 0
        draws = Map.get(share.season_record, "draws") || Map.get(share.season_record, :draws) || 0

        losses =
          Map.get(share.season_record, "losses") || Map.get(share.season_record, :losses) || 0

        pts = wins * 3 + draws
        record_str = "#{wins}W - #{draws}D - #{losses}L"

        status =
          cond do
            wins == 38 -> "Perfect 38-0-0 Season!"
            losses == 0 -> "Undefeated Invincible Season!"
            true -> "Finished with #{pts} Points!"
          end

        og_title = "My Retro Lineup: #{status}"

        og_desc =
          "Check out my #{share.formation} draft squad for the #{share.season_label || "retro"} season. Record: #{record_str}. Quote: \"#{share.funny_quote}\""

        socket =
          socket
          |> assign(:share, share)
          |> assign(:lineup, share.lineup)
          |> assign(:formation, share.formation)
          |> assign(:season_record, share.season_record)
          |> assign(:season_label, share.season_label)
          |> assign(:funny_quote, share.funny_quote)
          |> assign(:formation_layouts, GameLive.formation_layouts())
          |> assign(:page_title, "Shared Lineup - #{status}")
          |> assign(:og_title, og_title)
          |> assign(:og_description, og_desc)
          |> assign(:meta_description, og_desc)
          |> assign(:current_path, "/share/#{id}")

        {:ok, socket}

      _ ->
        socket =
          socket
          |> put_flash(:error, "Shared lineup not found or has expired.")
          |> redirect(to: "/")

        {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} record={@season_record} active_tab={:share} step={nil}>
      <div class="min-h-screen bg-[#f2f0eb] text-[rgba(0,0,0,0.87)] font-sans flex flex-col pb-12">
        <!-- Main container -->
        <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-6 flex-1 grid grid-cols-1 lg:grid-cols-12 gap-8 items-start w-full">
          <!-- Left 8 columns: Game Board & Lineup Pitch -->
          <div class="order-2 lg:order-1 lg:col-span-8 flex flex-col gap-6">
            <div class="bg-[#f2f0eb] flex flex-col gap-4">
              <!-- Soccer Pitch Lineup View -->
              <div class="relative bg-[#006241] border-4 border-[#1E3932] rounded-3xl p-6 overflow-hidden min-h-[660px] flex flex-col justify-between shadow-lg select-none">
                <!-- Soccer Pitch Lines -->
                <div class="absolute inset-4 border border-white/20 rounded-2xl pointer-events-none">
                </div>
                <div class="absolute inset-x-4 top-1/2 h-px bg-white/20 -translate-y-1/2 pointer-events-none">
                </div>
                <div class="absolute top-1/2 left-1/2 w-36 h-36 border border-white/20 rounded-full -translate-x-1/2 -translate-y-1/2 pointer-events-none">
                </div>
                <!-- Goal Areas / Penalty Boxes -->
                <div class="absolute top-4 left-1/2 -translate-x-1/2 w-80 h-32 border-b border-x border-white/10 pointer-events-none">
                </div>
                <div class="absolute bottom-4 left-1/2 -translate-x-1/2 w-80 h-32 border-t border-x border-white/10 pointer-events-none">
                </div>

                <% layout = Map.fetch!(@formation_layouts, @formation) %>
                <% slot_labels = InvinciblesWeb.GameLive.slot_labels(layout) %>
                
    <!-- Attacking Line -->
                <div class="flex justify-around items-center gap-2 z-10 mt-2">
                  <%= for pos <- layout.fwd do %>
                    <div class="pitch-slot flex flex-col items-center justify-center transition-all duration-200">
                      <%= if card = @lineup[pos] do %>
                        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#f43f5e] border-2 border-white/20 flex items-center justify-center text-white font-extrabold text-sm sm:text-base shadow-lg">
                          {elem(slot_labels[pos], 0)}
                        </div>
                        <div class="mt-2 px-2 py-1 bg-black/60 backdrop-blur-sm rounded-lg text-white text-[10px] sm:text-xs font-semibold shadow text-center whitespace-nowrap">
                          {truncate_name(card.player.display_name)}
                        </div>
                      <% else %>
                        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full border-2 border-dashed border-white/40 bg-black/20 backdrop-blur-sm flex items-center justify-center text-white/80 font-extrabold text-sm sm:text-base">
                          {elem(slot_labels[pos], 0)}
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
                
    <!-- Attacking Midfield Line (optional, e.g. 4-2-3-1) -->
                <%= if layout.amf != [] do %>
                  <div class="flex justify-around items-center gap-2 z-10 my-3">
                    <%= for pos <- layout.amf do %>
                      <div class="pitch-slot flex flex-col items-center justify-center transition-all duration-200">
                        <%= if card = @lineup[pos] do %>
                          <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#f43f5e] border-2 border-white/20 flex items-center justify-center text-white font-extrabold text-sm sm:text-base shadow-lg">
                            {elem(slot_labels[pos], 0)}
                          </div>
                          <div class="mt-2 px-2 py-1 bg-black/60 backdrop-blur-sm rounded-lg text-white text-[10px] sm:text-xs font-semibold shadow text-center whitespace-nowrap">
                            {truncate_name(card.player.display_name)}
                          </div>
                        <% else %>
                          <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full border-2 border-dashed border-white/40 bg-black/20 backdrop-blur-sm flex items-center justify-center text-white/80 font-extrabold text-sm sm:text-base">
                            {elem(slot_labels[pos], 0)}
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                <% end %>
                
    <!-- Midfield Line -->
                <div class="flex justify-around items-center gap-2 z-10 my-4">
                  <%= for pos <- layout.mid do %>
                    <div class="pitch-slot flex flex-col items-center justify-center transition-all duration-200">
                      <%= if card = @lineup[pos] do %>
                        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#f43f5e] border-2 border-white/20 flex items-center justify-center text-white font-extrabold text-sm sm:text-base shadow-lg">
                          {elem(slot_labels[pos], 0)}
                        </div>
                        <div class="mt-2 px-2 py-1 bg-black/60 backdrop-blur-sm rounded-lg text-white text-[10px] sm:text-xs font-semibold shadow text-center whitespace-nowrap">
                          {truncate_name(card.player.display_name)}
                        </div>
                      <% else %>
                        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full border-2 border-dashed border-white/40 bg-black/20 backdrop-blur-sm flex items-center justify-center text-white/80 font-extrabold text-sm sm:text-base">
                          {elem(slot_labels[pos], 0)}
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
                
    <!-- Defensive Line -->
                <div class="flex justify-around items-center gap-2 z-10">
                  <%= for pos <- layout.def do %>
                    <div class="pitch-slot flex flex-col items-center justify-center transition-all duration-200">
                      <%= if card = @lineup[pos] do %>
                        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#f43f5e] border-2 border-white/20 flex items-center justify-center text-white font-extrabold text-sm sm:text-base shadow-lg">
                          {elem(slot_labels[pos], 0)}
                        </div>
                        <div class="mt-2 px-2 py-1 bg-black/60 backdrop-blur-sm rounded-lg text-white text-[10px] sm:text-xs font-semibold shadow text-center whitespace-nowrap">
                          {truncate_name(card.player.display_name)}
                        </div>
                      <% else %>
                        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full border-2 border-dashed border-white/40 bg-black/20 backdrop-blur-sm flex items-center justify-center text-white/80 font-extrabold text-sm sm:text-base">
                          {elem(slot_labels[pos], 0)}
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
                
    <!-- Goalkeeper (GK) -->
                <div class="flex justify-center items-center z-10 mb-2">
                  <div class="pitch-slot flex flex-col items-center justify-center transition-all duration-200">
                    <%= if card = @lineup[:gk] do %>
                      <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#f43f5e] border-2 border-white/20 flex items-center justify-center text-white font-extrabold text-sm sm:text-base shadow-lg">
                        GK
                      </div>
                      <div class="mt-2 px-3 py-1 bg-black/60 backdrop-blur-sm rounded-lg text-white text-[10px] sm:text-xs font-semibold max-w-[80px] sm:max-w-[100px] truncate shadow">
                        {truncate_name(card.player.display_name)}
                      </div>
                    <% else %>
                      <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full border-2 border-dashed border-white/40 bg-black/20 backdrop-blur-sm flex items-center justify-center text-white/80 font-extrabold text-sm sm:text-base">
                        GK
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
              
    <!-- Standings table -->
              <% pts = @season_record.wins * 3 + @season_record.draws
              gd = @season_record.gf - @season_record.ga
              gd_str = if gd >= 0, do: "+#{gd}", else: "#{gd}"
              is_invincible = @season_record.losses == 0
              is_perfect = @season_record.wins == 38 %>
              <div id="standings-table-card">
                <div class={[
                  "rounded-t-xl px-6 py-4 flex items-center justify-between",
                  if(is_perfect,
                    do: "bg-gradient-to-r from-[#cba258] to-[#f0d47c]",
                    else:
                      if(is_invincible,
                        do: "bg-gradient-to-r from-[#006241] to-[#00754A]",
                        else: "bg-gradient-to-r from-[#1a1a1a] to-[#333]"
                      )
                  )
                ]}>
                  <div>
                    <div class="text-[10px] font-bold uppercase tracking-[1.2px] text-white/70 mb-0.5">
                      Shared Campaign
                      <%= if @season_label do %>
                        · {@season_label}
                      <% end %>
                    </div>
                    <div class="text-white font-black text-2xl tracking-tight leading-none">
                      {if is_perfect,
                        do: "PERFECT SEASON",
                        else: if(is_invincible, do: "INVINCIBLES", else: "FINAL RECORD")}
                    </div>
                  </div>
                  <div class="text-right">
                    <div class="text-white/60 text-[10px] uppercase tracking-wider">Points</div>
                    <div class="text-white font-black text-3xl leading-none">{pts}</div>
                  </div>
                </div>

                <div class="bg-white border-x border-[rgba(0,0,0,0.08)] px-6 py-5">
                  <div class="grid grid-cols-5 gap-2 text-center mb-5">
                    <div class="flex flex-col gap-1">
                      <span class="text-[22px] font-black text-[#006241] leading-none">
                        {@season_record.wins}
                      </span>
                      <span class="text-[9px] font-bold uppercase tracking-wider text-[rgba(0,0,0,0.4)]">
                        Won
                      </span>
                    </div>
                    <div class="flex flex-col gap-1">
                      <span class="text-[22px] font-black text-[rgba(0,0,0,0.5)] leading-none">
                        {@season_record.draws}
                      </span>
                      <span class="text-[9px] font-bold uppercase tracking-wider text-[rgba(0,0,0,0.4)]">
                        Drawn
                      </span>
                    </div>
                    <div class="flex flex-col gap-1">
                      <span class={[
                        "text-[22px] font-black leading-none",
                        if(@season_record.losses == 0, do: "text-[#006241]", else: "text-[#c82014]")
                      ]}>
                        {@season_record.losses}
                      </span>
                      <span class="text-[9px] font-bold uppercase tracking-wider text-[rgba(0,0,0,0.4)]">
                        Lost
                      </span>
                    </div>
                    <div class="flex flex-col gap-1">
                      <span class="text-[22px] font-black text-[rgba(0,0,0,0.75)] leading-none">
                        {@season_record.gf}
                      </span>
                      <span class="text-[9px] font-bold uppercase tracking-wider text-[rgba(0,0,0,0.4)]">
                        GF
                      </span>
                    </div>
                    <div class="flex flex-col gap-1">
                      <span class={[
                        "text-[22px] font-black leading-none",
                        if(gd >= 0, do: "text-[#006241]", else: "text-[#c82014]")
                      ]}>
                        {gd_str}
                      </span>
                      <span class="text-[9px] font-bold uppercase tracking-wider text-[rgba(0,0,0,0.4)]">
                        GD
                      </span>
                    </div>
                  </div>

                  <div class={[
                    "text-center text-sm sm:text-base leading-relaxed italic mt-3 px-4",
                    if(is_perfect,
                      do: "text-[#7a5c1e] font-semibold",
                      else:
                        if(is_invincible,
                          do: "text-[#006241] font-semibold",
                          else: "text-[rgba(0,0,0,0.78)] font-medium"
                        )
                    )
                  ]}>
                    "{@funny_quote}"
                  </div>
                </div>

                <div class="bg-[#f7f7f5] border border-[rgba(0,0,0,0.08)] rounded-b-xl px-6 py-4 flex items-center justify-between">
                  <span class="text-[10px] text-[rgba(0,0,0,0.4)]">
                    GA: {@season_record.ga} · Pts: {pts}
                  </span>
                </div>
              </div>
            </div>
          </div>
          
    <!-- Right 4 columns: Play Call-To-Action -->
          <div class="order-1 lg:order-2 lg:col-span-4 flex flex-col gap-6">
            <div class="card-starbucks p-6 flex flex-col gap-6 text-center">
              <div class="w-12 h-12 mx-auto bg-[#edebe9] border border-[rgba(0,0,0,0.08)] rounded-[12px] flex items-center justify-center">
                <.icon name="hero-trophy" class="w-6 h-6 text-[#00754A]" />
              </div>
              <h2 class="text-[20px] font-bold tracking-tight mb-2 text-[#006241]">
                Build your own Invincibles squad!
              </h2>
              <p class="text-xs text-[rgba(0,0,0,0.58)] leading-relaxed mb-4">
                Can you draft historical Premier League players and lead them to a perfect, undefeated 38-game season?
              </p>
              <.link navigate="/" class="w-full btn-starbucks btn-starbucks-filled text-sm block py-3">
                PLAY NOW
              </.link>
            </div>
          </div>
        </main>
      </div>
    </Layouts.app>
    """
  end

  defp truncate_name(name) do
    case String.split(name, " ") do
      [single] -> single
      parts -> List.last(parts)
    end
  end
end
