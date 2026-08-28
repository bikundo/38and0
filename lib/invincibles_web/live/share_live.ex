defmodule InvinciblesWeb.ShareLive do
  use InvinciblesWeb, :live_view
  alias Invincibles.Game
  alias InvinciblesWeb.GameLive

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Game.get_share(id) do
      {:ok, share} ->
        wins = share.season_record.wins
        draws = share.season_record.draws
        losses = share.season_record.losses

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
        <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-6 flex-1 grid grid-cols-1 lg:grid-cols-12 gap-8 items-start w-full">
          <div class="order-2 lg:order-1 lg:col-span-8 flex flex-col gap-6">
            <div class="bg-[#f2f0eb] flex flex-col gap-4">
              <.pitch_board
                lineup={@lineup}
                formation={@formation}
                formation_layouts={@formation_layouts}
                interactive={false}
              />

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
end
