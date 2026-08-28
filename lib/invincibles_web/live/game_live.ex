defmodule InvinciblesWeb.GameLive do
  use InvinciblesWeb, :live_view
  alias Invincibles.Game
  alias Invincibles.Game.SimEngine

  @positions_mapping %{
    "GK" => [:gk],
    "DF" => [:lb, :cb1, :cb2, :cb3, :rb],
    "MF" => [:lm, :cm, :cm1, :cm2, :cm3, :rm],
    "FW" => [:lw, :st, :st1, :st2, :rw]
  }

  @formation_layouts %{
    "4-3-3" => %{
      def: [:lb, :cb1, :cb2, :rb],
      amf: [],
      mid: [:lm, :cm, :rm],
      fwd: [:lw, :st, :rw]
    },
    "4-4-2" => %{
      def: [:lb, :cb1, :cb2, :rb],
      amf: [],
      mid: [:lm, :cm1, :cm2, :rm],
      fwd: [:st1, :st2]
    },
    "3-5-2" => %{
      def: [:cb1, :cb2, :cb3],
      amf: [],
      mid: [:lm, :cm1, :cm2, :cm3, :rm],
      fwd: [:st1, :st2]
    },
    "4-2-3-1" => %{
      def: [:lb, :cb1, :cb2, :rb],
      amf: [:lm, :cm3, :rm],
      mid: [:cm1, :cm2],
      fwd: [:st]
    },
    "4-1-4-1" => %{
      def: [:lb, :cb1, :cb2, :rb],
      amf: [:lm, :cm2, :cm3, :rm],
      mid: [:cm1],
      fwd: [:st]
    },
    "4-5-1" => %{
      def: [:lb, :cb1, :cb2, :rb],
      amf: [],
      mid: [:lm, :cm1, :cm2, :cm3, :rm],
      fwd: [:st]
    },
    "3-4-3" => %{
      def: [:cb1, :cb2, :cb3],
      amf: [],
      mid: [:lm, :cm1, :cm2, :rm],
      fwd: [:lw, :st, :rw]
    },
    "5-3-2" => %{
      def: [:lb, :cb1, :cb2, :cb3, :rb],
      amf: [],
      mid: [:lm, :cm, :rm],
      fwd: [:st1, :st2]
    }
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, reset_state(socket)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    tab =
      case params["tab"] do
        "leaderboard" -> :leaderboard
        "simulation" -> :simulation
        _ -> :draft
      end

    socket =
      if tab == :leaderboard do
        shares = Game.list_active_shares()
        total_games = Game.count_all_shares()

        socket
        |> assign(shares: shares)
        |> assign(total_games_played: total_games)
      else
        socket
      end

    current_path =
      case tab do
        :leaderboard -> "/?tab=leaderboard"
        :simulation -> "/?tab=simulation"
        _ -> "/"
      end

    page_title =
      case tab do
        :leaderboard -> "Leaderboard - retro drafting campaigns"
        _ -> "Play Retro Premier League Draft Simulator"
      end

    meta_description =
      "Draft legendary players from the 90s, 00s, 10s, or 20s. Build custom formations, simulate matches, and lead your squad to an undefeated 38-0-0 season."

    socket =
      socket
      |> assign(:active_tab, tab)
      |> assign(:page_title, page_title)
      |> assign(:meta_description, meta_description)
      |> assign(:current_path, current_path)

    socket =
      case {params["club_id"], params["season"]} do
        {club_id_str, season} when is_binary(club_id_str) and is_binary(season) ->
          case Integer.parse(club_id_str) do
            {club_id, ""} ->
              case Invincibles.Repo.get(Game.Club, club_id) do
                nil ->
                  socket

                club ->
                  appearances = Game.list_appearances_for_spin(club.id, season)

                  socket
                  |> assign(:step, :drafting)
                  |> assign(:current_spin, {club, season})
                  |> assign(:draft_pool, appearances)
              end

            _ ->
              socket
          end

        _ ->
          socket
      end

    {:noreply, socket}
  end

  defp reset_state(socket) do
    socket
    |> assign(:step, :not_started)
    |> assign(:budget, 200_000_000)
    |> assign(:current_spin, nil)
    |> assign(:draft_pool, [])
    |> assign(:search_filter, "")
    |> assign(:formation, "4-3-3")
    |> assign(:formation_layouts, @formation_layouts)
    |> assign(:lineup, %{
      gk: nil,
      lb: nil,
      cb1: nil,
      cb2: nil,
      cb3: nil,
      rb: nil,
      lm: nil,
      cm: nil,
      cm1: nil,
      cm2: nil,
      cm3: nil,
      rm: nil,
      lw: nil,
      rw: nil,
      st: nil,
      st1: nil,
      st2: nil
    })
    |> assign(:season_record, %{week: 0, wins: 0, draws: 0, losses: 0, gf: 0, ga: 0})
    |> assign(:sim_results, nil)
    |> assign(:simulating_week, nil)
    |> assign(:active_tab, :draft)
    |> assign(:shares, [])
    |> assign(:active_share, nil)
    |> assign(:total_games_played, 0)
  end

  @doc """
  Returns formation-aware position labels for each slot in a given layout.
  Each slot maps to a tuple of `{abbreviation, full_name}`, e.g. `{"CDM", "Def. Mid"}`.
  """
  def slot_labels(layout) do
    gk = %{gk: {"GK", "Goalkeeper"}}

    def_count = length(layout.def)

    def_labels =
      Enum.into(layout.def, %{}, fn slot ->
        {slot,
         case slot do
           :lb -> if def_count == 5, do: {"LWB", "Wing-Back"}, else: {"LB", "Left Back"}
           :rb -> if def_count == 5, do: {"RWB", "Wing-Back"}, else: {"RB", "Right Back"}
           _ -> {"CB", "Centre Back"}
         end}
      end)

    has_amf = layout.amf != []

    amf_labels =
      case layout.amf do
        [] ->
          %{}

        [single] ->
          %{single => {"CAM", "Att. Mid"}}

        [l, c, r] ->
          %{
            l => {"LAM", "Left Att. Mid"},
            c => {"CAM", "Att. Mid"},
            r => {"RAM", "Right Att. Mid"}
          }

        [l, lc, rc, r] ->
          %{
            l => {"LM", "Left Mid"},
            lc => {"LCM", "Left CM"},
            rc => {"RCM", "Right CM"},
            r => {"RM", "Right Mid"}
          }

        other ->
          Map.new(other, fn s -> {s, {"AM", "Att. Mid"}} end)
      end

    mid_labels =
      case {length(layout.mid), has_amf} do
        {1, _} ->
          [m] = layout.mid
          %{m => {"CDM", "Def. Mid"}}

        {2, true} ->
          [m1, m2] = layout.mid
          %{m1 => {"CDM", "Def. Mid"}, m2 => {"CDM", "Def. Mid"}}

        {2, false} ->
          [m1, m2] = layout.mid
          %{m1 => {"CM", "Central Mid"}, m2 => {"CM", "Central Mid"}}

        {3, _} ->
          [m1, m2, m3] = layout.mid
          %{m1 => {"LM", "Left Mid"}, m2 => {"CM", "Central Mid"}, m3 => {"RM", "Right Mid"}}

        {4, _} ->
          [m1, m2, m3, m4] = layout.mid

          %{
            m1 => {"LM", "Left Mid"},
            m2 => {"CM", "Central Mid"},
            m3 => {"CM", "Central Mid"},
            m4 => {"RM", "Right Mid"}
          }

        {5, _} ->
          [m1, m2, m3, m4, m5] = layout.mid

          %{
            m1 => {"LM", "Left Mid"},
            m2 => {"CM", "Central Mid"},
            m3 => {"CM", "Central Mid"},
            m4 => {"CM", "Central Mid"},
            m5 => {"RM", "Right Mid"}
          }

        _ ->
          Map.new(layout.mid, fn s -> {s, {"CM", "Central Mid"}} end)
      end

    fwd_labels =
      case layout.fwd do
        [:lw, :st, :rw] ->
          %{lw: {"LW", "Left Wing"}, st: {"ST", "Striker"}, rw: {"RW", "Right Wing"}}

        [:st1, :st2] ->
          %{st1: {"ST", "Striker"}, st2: {"ST", "Striker"}}

        [:st] ->
          %{st: {"ST", "Striker"}}

        _ ->
          Map.new(layout.fwd, fn s -> {s, {"FW", "Forward"}} end)
      end

    gk
    |> Map.merge(def_labels)
    |> Map.merge(amf_labels)
    |> Map.merge(mid_labels)
    |> Map.merge(fwd_labels)
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    formation = socket.assigns.formation

    socket =
      reset_state(socket)
      |> assign(:formation, formation)
      |> assign(:step, :spinning)
      |> push_event("auto_spin", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("spin_wheel", _params, socket) do
    case Game.spin_wheel() do
      {:ok, club, season, appearances} ->
        # IMPORTANT: do NOT assign step: :drafting here.
        # If we do, LiveView removes the :spinning DOM (and the SpinWheel hook)
        # before spin_result_ready is received — so handleEvent never fires.
        # We keep the hook alive and let it call animation_done when ready.
        socket =
          socket
          |> assign(:current_spin, {club, season})
          |> assign(:draft_pool, appearances)
          |> clear_flash()
          |> push_event("spin_result_ready", %{club: club.name, season: season})

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Failed to load database players. Make sure the database is seeded."
         )}
    end
  end

  @impl true
  def handle_event("animation_done", _params, socket) do
    # Called by the JS hook after the overlay has fully dismissed.
    # Now safe to transition to :drafting — the overlay is gone, the
    # player list will be revealed cleanly.
    {:noreply, assign(socket, :step, :drafting)}
  end

  @impl true
  def handle_event("filter_draft", %{"value" => query}, socket) do
    {:noreply, assign(socket, :search_filter, query)}
  end

  @impl true
  def handle_event("select_formation", %{"formation" => formation}, socket) do
    {:noreply, assign(socket, :formation, formation)}
  end

  @impl true
  def handle_event("auto_draft", _params, socket) do
    layout = Map.fetch!(@formation_layouts, socket.assigns.formation)
    active_slots = [:gk | layout.def ++ layout.amf ++ layout.mid ++ layout.fwd]
    new_lineup = Game.auto_draft_lineup(socket.assigns.lineup, active_slots)

    socket =
      socket
      |> assign(:lineup, new_lineup)
      |> assign(:step, :squad_complete)
      |> assign(:current_spin, nil)
      |> assign(:draft_pool, [])
      |> clear_flash()

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "draft_player",
        %{"appearance-id" => app_id, "position-key" => pos_key_str},
        socket
      ) do
    app_id = String.to_integer(app_id)
    pos_key = String.to_existing_atom(pos_key_str)
    appearance = Game.get_appearance(app_id)

    cond do
      not is_nil(Map.get(socket.assigns.lineup, pos_key)) ->
        {:noreply, put_flash(socket, :error, "Position slot already occupied!")}

      true ->
        new_lineup = Map.put(socket.assigns.lineup, pos_key, appearance)

        layout = Map.fetch!(@formation_layouts, socket.assigns.formation)
        active_slots = [:gk | layout.def ++ layout.amf ++ layout.mid ++ layout.fwd]

        squad_complete =
          Enum.all?(active_slots, fn slot -> not is_nil(Map.get(new_lineup, slot)) end)

        new_step = if squad_complete, do: :squad_complete, else: :spinning

        socket =
          socket
          |> assign(:lineup, new_lineup)
          |> assign(:draft_pool, [])
          |> assign(:current_spin, nil)
          |> assign(:step, new_step)
          |> clear_flash()

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("share_lineup", _params, socket) do
    case socket.assigns[:active_share] do
      %Game.Share{} = share ->
        url = url(~p"/share/#{share.id}")
        {:noreply, push_event(socket, "share_url", %{url: url})}

      _ ->
        lineup = socket.assigns.lineup
        formation = socket.assigns.formation
        record = socket.assigns.season_record

        season_label =
          if socket.assigns.sim_results,
            do: Map.get(socket.assigns.sim_results, :season_label, ""),
            else: ""

        funny_quote = get_funny_quote(record)

        case Game.create_share(lineup, formation, record, season_label, funny_quote) do
          {:ok, share} ->
            url = url(~p"/share/#{share.id}")

            {:noreply,
             socket
             |> assign(:active_share, share)
             |> push_event("share_url", %{url: url})}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to generate share link.")}
        end
    end
  end

  @impl true
  def handle_event("simulate_season", _params, socket) do
    strengths = SimEngine.calculate_strengths(socket.assigns.lineup)
    results = SimEngine.simulate_season(strengths)

    socket =
      socket
      |> assign(:step, :simulating)
      |> assign(:sim_results, results)
      |> assign(:simulating_week, 1)

    Process.send_after(self(), :tick_simulation, 150)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:tick_simulation, socket) do
    current_week = socket.assigns.simulating_week
    results = socket.assigns.sim_results

    if current_week <= 38 do
      matches_so_far = Enum.take(results.matches, current_week)

      wins = Enum.count(matches_so_far, &(&1.result == :win))
      draws = Enum.count(matches_so_far, &(&1.result == :draw))
      losses = Enum.count(matches_so_far, &(&1.result == :loss))
      gf = Enum.sum(Enum.map(matches_so_far, & &1.gf))
      ga = Enum.sum(Enum.map(matches_so_far, & &1.ga))

      new_record = %{
        week: current_week,
        wins: wins,
        draws: draws,
        losses: losses,
        gf: gf,
        ga: ga
      }

      socket =
        socket
        |> assign(:season_record, new_record)
        |> assign(:simulating_week, current_week + 1)

      Process.send_after(self(), :tick_simulation, 150)
      {:noreply, socket}
    else
      final_step =
        cond do
          results.wins == 38 -> :hall_of_fame
          results.losses == 0 -> :hall_of_fame
          true -> :game_over
        end

      lineup = socket.assigns.lineup
      formation = socket.assigns.formation
      record = socket.assigns.season_record
      season_label = Map.get(results, :season_label, "")
      funny_quote = get_funny_quote(record)

      socket =
        case Game.create_share(lineup, formation, record, season_label, funny_quote) do
          {:ok, share} ->
            assign(socket, :active_share, share)

          {:error, _changeset} ->
            socket
        end

      socket =
        socket
        |> assign(:step, final_step)

      {:noreply, socket}
    end
  end

  defp compatible_empty_slots(lineup, primary_position, active_slots) do
    slots = Map.get(@positions_mapping, primary_position, [])
    active_matching_slots = Enum.filter(slots, &Enum.member?(active_slots, &1))
    Enum.filter(active_matching_slots, &is_nil(Map.get(lineup, &1)))
  end

  defp player_already_drafted?(lineup, player_id) do
    Enum.any?(lineup, fn {_, app} ->
      not is_nil(app) and app.player_id == player_id
    end)
  end

  defp get_funny_quote(record) do
    points = record.wins * 3 + record.draws
    losses = record.losses
    ga = record.ga

    cond do
      record.wins == 38 ->
        "A perfect 38-0-0! Pep Guardiola is calling for your tactical blueprint. Absolutely insane."

      losses == 0 ->
        "Unbeaten! You matched the legendary Arsenal 2003/04 Invincibles. Arsene Wenger has a tear in his eye."

      points >= 100 ->
        "#{points} points! You matched the Man City 2017/18 'Centurions' record. Truly elite."

      points >= 90 ->
        "#{points} points! You matched the elite standard of Chelsea 2005/06 or Man City 2018/19 champions."

      ga <= 15 ->
        "Only #{ga} goals conceded! Jose Mourinho is nodding in approval. You matched Chelsea's 2004/05 defensive masterclass."

      points >= 75 ->
        "A fantastic #{points}-point campaign! You secured Champions League football, but the Invincibles dream awaits."

      points >= 50 ->
        "A respectable #{points}-point season. Your squad played some beautiful football, but did it have the grit of Sean Dyche's Burnley?"

      points >= 38 ->
        "You reached the safety threshold, but Sam Allardyce is confident he could have kept this team up with 10 matches to spare."

      points >= 20 ->
        "You finished with #{points} points. Relegation confirmed. Even Roy Hodgson couldn't guide this squad to safety."

      true ->
        "Dangerously close to matching Derby County's 2007/08 record of 11 points! Time to overhaul the squad."
    end
  end

  defp number_to_delimited(num) when is_integer(num) do
    num
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  attr :match, :map, required: true

  defp match_row(assigns) do
    result_badge_color =
      cond do
        assigns.match.result == :win -> "text-[#00754A]"
        assigns.match.result == :draw -> "text-[#cba258]"
        true -> "text-[#c82014]"
      end

    assigns = assign(assigns, :result_badge_color, result_badge_color)

    ~H"""
    <div class="flex items-center justify-between border border-[rgba(0,0,0,0.08)] bg-white p-3 rounded-lg shadow-sm text-[rgba(0,0,0,0.87)]">
      <div class="flex items-center gap-2">
        <span class="text-xs font-semibold text-[rgba(0,0,0,0.58)]">
          GW {@match.week}
        </span>
        <span class="text-xs font-semibold">
          INVINCIBLES {@match.gf} - {@match.ga} {Map.get(@match, :opponent_short, "OPPONENT")}
        </span>
      </div>
      <span class={[
        "text-[9px] font-bold uppercase tracking-widest px-2 py-0.5 rounded bg-black/5",
        @result_badge_color
      ]}>
        {@match.result}
      </span>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} record={@season_record} active_tab={@active_tab} step={@step}>
      <div class="min-h-screen bg-[#f2f0eb] text-[rgba(0,0,0,0.87)] font-sans flex flex-col pb-12">
        <%= if @active_tab == :leaderboard do %>
          <main class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 mt-6 flex-1 w-full flex flex-col gap-6">
            <div class="card-starbucks p-6 md:p-8 flex flex-col gap-6">
              <div class="flex flex-col md:flex-row md:items-center justify-between border-b border-[rgba(0,0,0,0.08)] pb-6 gap-4">
                <div class="flex items-center gap-4">
                  <div class="w-12 h-12 bg-[#edebe9] border border-[rgba(0,0,0,0.08)] rounded-[12px] flex items-center justify-center">
                    <.icon name="hero-trophy" class="w-6 h-6 text-[#00754A]" />
                  </div>
                  <div>
                    <h1 class="text-2xl font-black tracking-tight text-[#006241]">
                      Manager Leaderboard
                    </h1>
                    <p class="text-xs text-[rgba(0,0,0,0.58)] mt-0.5 font-medium">
                      The best campaigns from managers worldwide · {number_to_delimited(
                        @total_games_played
                      )} total games played
                    </p>
                  </div>
                </div>

                <%= if @step == :not_started do %>
                  <.link
                    navigate={~p"/"}
                    class="btn-starbucks btn-starbucks-filled text-sm py-3 px-6 text-center whitespace-nowrap self-start md:self-auto"
                  >
                    PLAY NOW
                  </.link>
                <% else %>
                  <.link
                    navigate={~p"/"}
                    class="btn-starbucks btn-starbucks-filled text-sm py-3 px-6 text-center whitespace-nowrap self-start md:self-auto"
                  >
                    RESUME PLAY
                  </.link>
                <% end %>
              </div>

              <%= if @shares == [] do %>
                <div class="text-center py-16 flex flex-col items-center justify-center">
                  <div class="w-16 h-16 bg-[#edebe9] rounded-full flex items-center justify-center mb-4 border border-[rgba(0,0,0,0.06)]">
                    <.icon name="hero-no-symbol" class="w-8 h-8 text-[rgba(0,0,0,0.4)]" />
                  </div>
                  <h3 class="text-lg font-bold text-[#006241] mb-1">No campaigns active</h3>
                  <p class="text-xs text-[rgba(0,0,0,0.58)] max-w-sm mb-6 leading-relaxed">
                    No managers have shared their campaigns recently. Draft your squad, finish the 38-game season, and share your lineup to claim your spot on the board.
                  </p>
                  <.link
                    navigate={~p"/"}
                    class="btn-starbucks btn-starbucks-filled text-sm py-2.5 px-5"
                  >
                    PLAY NOW
                  </.link>
                </div>
              <% else %>
                <div class="overflow-x-auto">
                  <table class="w-full text-left border-collapse text-xs md:text-sm">
                    <thead>
                      <tr class="border-b border-[rgba(0,0,0,0.08)] text-[10px] font-bold uppercase tracking-wider text-[rgba(0,0,0,0.4)] font-semibold">
                        <th class="pb-3 pl-2 w-12 text-center">Rank</th>
                        <th class="pb-3 pl-4">Campaign</th>
                        <th class="pb-3 text-center w-20 hidden sm:table-cell">Formation</th>
                        <th class="pb-3 text-center w-32 hidden md:table-cell">Record (W-D-L)</th>
                        <th class="pb-3 text-center w-20 hidden sm:table-cell">GD</th>
                        <th class="pb-3 text-center w-20">Points</th>
                        <th class="pb-3 pr-2 text-right w-28">Action</th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-[rgba(0,0,0,0.04)]">
                      <%= for {share, idx} <- Enum.with_index(@shares, 1) do %>
                        <% wins = share.season_record.wins
                        draws = share.season_record.draws
                        losses = share.season_record.losses
                        gf = share.season_record.gf
                        ga = share.season_record.ga

                        pts = wins * 3 + draws
                        gd = gf - ga
                        gd_str = if gd >= 0, do: "+#{gd}", else: "#{gd}"
                        is_perfect = wins == 38
                        is_invincible = losses == 0 %>
                        <tr class="hover:bg-[rgba(0,0,0,0.02)] transition-colors duration-150 cursor-pointer group">
                          <td
                            class="py-4 pl-2 text-center font-bold"
                            phx-click={JS.navigate(~p"/share/#{share.id}")}
                          >
                            <%= cond do %>
                              <% idx == 1 -> %>
                                <span class="inline-flex items-center justify-center w-6 h-6 rounded-full bg-[#f0d47c] text-[#7a5c1e] text-[11px] shadow-sm">
                                  1
                                </span>
                              <% idx == 2 -> %>
                                <span class="inline-flex items-center justify-center w-6 h-6 rounded-full bg-[#edebe9] text-[rgba(0,0,0,0.6)] text-[11px] shadow-sm">
                                  2
                                </span>
                              <% idx == 3 -> %>
                                <span class="inline-flex items-center justify-center w-6 h-6 rounded-full bg-[#dfc6a3] text-[#78593a] text-[11px] shadow-sm">
                                  3
                                </span>
                              <% true -> %>
                                <span class="text-[rgba(0,0,0,0.58)]">{idx}</span>
                            <% end %>
                          </td>
                          <td class="py-4 pl-4" phx-click={JS.navigate(~p"/share/#{share.id}")}>
                            <div class="flex flex-col gap-0.5">
                              <div class="font-bold text-[rgba(0,0,0,0.87)] flex items-center gap-1.5 flex-wrap">
                                <span class="group-hover:text-[#00754A] transition-colors">
                                  {share.season_label || "Season Record"}
                                </span>
                                <%= if is_perfect do %>
                                  <span class="bg-[#f0d47c] text-[#7a5c1e] text-[9px] font-bold px-1.5 py-0.5 rounded uppercase tracking-wider">
                                    Perfect
                                  </span>
                                <% else %>
                                  <%= if is_invincible do %>
                                    <span class="bg-[#00754A] text-white text-[9px] font-bold px-1.5 py-0.5 rounded uppercase tracking-wider">
                                      Invincible
                                    </span>
                                  <% end %>
                                <% end %>
                              </div>
                              <div class="text-[11px] italic text-[rgba(0,0,0,0.5)] line-clamp-1 group-hover:text-[rgba(0,0,0,0.65)] transition-colors">
                                "{share.funny_quote}"
                              </div>
                            </div>
                          </td>
                          <td
                            class="py-4 text-center font-mono text-xs hidden sm:table-cell"
                            phx-click={JS.navigate(~p"/share/#{share.id}")}
                          >
                            <span class="bg-[#edebe9] text-[rgba(0,0,0,0.68)] px-2 py-0.5 rounded font-semibold">
                              {share.formation}
                            </span>
                          </td>
                          <td
                            class="py-4 text-center font-semibold text-[rgba(0,0,0,0.87)] hidden md:table-cell"
                            phx-click={JS.navigate(~p"/share/#{share.id}")}
                          >
                            {wins}W - {draws}D - {losses}L
                          </td>
                          <td
                            class={[
                              "py-4 text-center font-bold hidden sm:table-cell",
                              if(gd >= 0, do: "text-[#00754A]", else: "text-[#c82014]")
                            ]}
                            phx-click={JS.navigate(~p"/share/#{share.id}")}
                          >
                            {gd_str}
                          </td>
                          <td
                            class="py-4 text-center font-black text-sm text-[rgba(0,0,0,0.87)]"
                            phx-click={JS.navigate(~p"/share/#{share.id}")}
                          >
                            {pts}
                          </td>
                          <td class="py-4 pr-2 text-right">
                            <.link
                              navigate={~p"/share/#{share.id}"}
                              class="inline-flex items-center justify-center border border-[rgba(0,0,0,0.12)] hover:border-[#00754A] hover:bg-[#00754A] hover:text-white transition-all text-xs font-bold py-1.5 px-3 rounded-lg text-[rgba(0,0,0,0.68)] shadow-sm whitespace-nowrap"
                            >
                              VIEW SQUAD
                            </.link>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% end %>
            </div>
          </main>
        <% else %>
          <main
            id="game-main-container"
            phx-hook="DragDropLineup"
            class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-6 flex-1 grid grid-cols-1 lg:grid-cols-12 gap-8 items-start w-full"
          >
            <div class="order-2 lg:order-1 lg:col-span-8 flex flex-col gap-6">
              <div id="share-capture-area" class="bg-[#f2f0eb] flex flex-col gap-4">
                <.pitch_board
                  lineup={@lineup}
                  formation={@formation}
                  formation_layouts={@formation_layouts}
                  interactive={true}
                />
              </div>

              <%!-- Mobile Match History --%>
              <%= if @step in [:game_over, :hall_of_fame] and @sim_results && @sim_results.matches != [] do %>
                <div class="block lg:hidden card-starbucks p-6 flex flex-col gap-4 mt-6">
                  <div class="flex items-center justify-between pb-3 mb-1 border-b border-[rgba(0,0,0,0.08)]">
                    <span class="text-[11px] font-bold text-[rgba(0,0,0,0.4)] uppercase tracking-[0.6px]">
                      Match History
                    </span>
                  </div>
                  <div class="flex flex-col gap-2 max-h-[300px] overflow-y-auto pr-1">
                    <%= for match <- Enum.reverse(@sim_results.matches) do %>
                      <.match_row match={match} />
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>

            <div class="order-1 lg:order-2 lg:col-span-4 flex flex-col gap-6">
              <%= if @step not in [:game_over, :hall_of_fame] do %>
                <div class="card-starbucks p-6 flex flex-col gap-6">
                  <%= if @step == :not_started do %>
                    <div class="text-center py-6">
                      <div class="w-12 h-12 mx-auto bg-[#edebe9] border border-[rgba(0,0,0,0.08)] rounded-[12px] flex items-center justify-center mb-4">
                        <.icon name="hero-trophy" class="w-6 h-6 text-[#00754A]" />
                      </div>
                      <h2 class="text-[20px] font-bold tracking-tight mb-2 text-[#006241]">
                        Can you build an Invincible squad?
                      </h2>
                      <p class="text-xs text-[rgba(0,0,0,0.58)] leading-relaxed mb-6">
                        Draft an 11-man squad using historical Premier League players. Each round, you spin the wheel to draw a random club and season, then draft from eligible players. Go undefeated over a 38-game season to cement your status as an Invincible.
                      </p>

                      <%!-- Formation Selection --%>
                      <div class="mb-6 text-left">
                        <label class="text-[10px] font-semibold text-[rgba(0,0,0,0.58)] uppercase tracking-[0.6px] block mb-2">
                          Select Formation
                        </label>
                        <div class="grid grid-cols-4 gap-2">
                          <%= for form_name <- ["4-3-3", "4-4-2", "4-2-3-1", "4-1-4-1", "4-5-1", "3-4-3", "3-5-2", "5-3-2"] do %>
                            <button
                              type="button"
                              phx-click="select_formation"
                              phx-value-formation={form_name}
                              class={[
                                "py-2 px-3 text-xs font-semibold rounded-lg border transition-all duration-150",
                                if(@formation == form_name,
                                  do: "bg-[#00754A] text-white border-[#00754A]",
                                  else:
                                    "bg-white text-[rgba(0,0,0,0.87)] border-[rgba(0,0,0,0.12)] hover:border-[#00754A]"
                                )
                              ]}
                            >
                              {form_name}
                            </button>
                          <% end %>
                        </div>
                      </div>

                      <div class="flex flex-col gap-2.5">
                        <button
                          phx-click="start_game"
                          class="w-full btn-starbucks btn-starbucks-filled text-sm"
                        >
                          START DRAFT
                        </button>
                        <button
                          phx-click="auto_draft"
                          class="w-full btn-starbucks btn-starbucks-black text-sm"
                        >
                          AUTO DRAFT SQUAD
                        </button>
                      </div>
                    </div>
                  <% end %>

                  <%= if @step == :spinning do %>
                    <div class="text-center py-6">
                      <div
                        id="spin-wheel-container"
                        class="w-14 h-14 mx-auto bg-[#edebe9] border border-[rgba(0,0,0,0.08)] rounded-full flex items-center justify-center mb-4 shadow-sm"
                      >
                        <.icon name="hero-arrow-path" class="w-6 h-6 text-[#00754A]" />
                      </div>
                      <h2 class="text-[20px] font-bold tracking-tight mb-2 text-[#006241]">
                        Draw Club & Season
                      </h2>
                      <p class="text-xs text-[rgba(0,0,0,0.58)] leading-relaxed mb-6 max-w-xs mx-auto">
                        Every player draft pick is restricted to a specific Premier League club and season. Spin the wheel to reveal your next requirement.
                      </p>
                      <div class="flex flex-col gap-2.5">
                        <button
                          id="spin-btn"
                          phx-hook="SpinWheel"
                          class="w-full btn-starbucks btn-starbucks-filled btn-spin-wheel text-sm"
                        >
                          Spin the Wheel
                        </button>
                        <button
                          phx-click="auto_draft"
                          class="w-full btn-starbucks btn-starbucks-black text-sm"
                        >
                          Auto Draft Remaining
                        </button>
                      </div>
                    </div>
                  <% end %>

                  <%= if @step == :drafting do %>
                    <div>
                      <div class="flex items-center justify-between border-b border-[rgba(0,0,0,0.08)] pb-3 mb-4">
                        <span class="text-[11px] font-semibold text-[rgba(0,0,0,0.58)] uppercase tracking-[0.6px]">
                          Active Club & Season
                        </span>
                        <span class="text-[#00754A] text-[11px] font-semibold uppercase tracking-[0.6px]">
                          Drafting
                        </span>
                      </div>

                      <%= if @current_spin do %>
                        <% {club, season} = @current_spin %>
                        <div
                          id="spin-result-card"
                          class="flex items-center justify-between bg-[#edebe9] border border-[rgba(0,0,0,0.08)] rounded-lg p-3.5 mb-4"
                        >
                          <span class="font-bold text-sm text-[rgba(0,0,0,0.87)]">{club.name}</span>
                          <span class="text-[rgba(0,0,0,0.58)] text-xs font-semibold uppercase tracking-[0.6px]">
                            {season}
                          </span>
                        </div>
                      <% end %>

                      <%!-- Search Bar --%>
                      <div class="relative mb-4">
                        <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                          <.icon
                            name="hero-magnifying-glass"
                            class="w-3.5 h-3.5 text-[rgba(0,0,0,0.38)]"
                          />
                        </div>
                        <input
                          id="draft-search"
                          type="text"
                          placeholder="Search players..."
                          phx-keyup="filter_draft"
                          phx-debounce="150"
                          value={@search_filter}
                          class="w-full bg-[#f9f9f9] border border-[rgba(0,0,0,0.12)] rounded-lg pl-9 pr-3 py-2 text-xs text-[rgba(0,0,0,0.87)] placeholder-[rgba(0,0,0,0.38)] focus:outline-none focus:border-[#00754A] focus:ring-1 focus:ring-[#00754A] transition-colors"
                        />
                      </div>

                      <div class="flex items-center justify-between mb-3">
                        <span class="text-[11px] font-semibold text-[rgba(0,0,0,0.58)] uppercase tracking-[0.6px]">
                          Draft Pool
                        </span>
                        <button
                          type="button"
                          phx-click="auto_draft"
                          class="text-[#00754A] hover:text-[#006241] text-[10px] font-bold uppercase tracking-[0.6px] transition-colors"
                        >
                          Auto Draft
                        </button>
                      </div>

                      <%= if Enum.empty?(@draft_pool) do %>
                        <div class="text-center py-6 bg-[#edebe9] rounded-lg border border-dashed border-[rgba(0,0,0,0.12)]">
                          <p class="text-xs text-[rgba(0,0,0,0.58)] mb-4">
                            No historical players found for this club and season.
                          </p>
                          <div class="flex flex-col gap-2">
                            <button
                              phx-click="spin_wheel"
                              class="btn-starbucks btn-starbucks-outlined text-xs"
                            >
                              SPIN AGAIN
                            </button>
                            <button
                              phx-click="auto_draft"
                              class="btn-starbucks btn-starbucks-black text-xs"
                            >
                              AUTO DRAFT REMAINING
                            </button>
                          </div>
                        </div>
                      <% else %>
                        <% search_lower = String.downcase(@search_filter) %>
                        <% filtered_pool =
                          if @search_filter == "",
                            do: @draft_pool,
                            else:
                              Enum.filter(@draft_pool, fn app ->
                                String.contains?(
                                  String.downcase(app.player.display_name),
                                  search_lower
                                )
                              end) %>

                        <div class="flex flex-col gap-1 max-h-[420px] overflow-y-auto pr-1">
                          <%= if Enum.empty?(filtered_pool) do %>
                            <div class="text-center py-4">
                              <p class="text-xs text-[rgba(0,0,0,0.38)]">
                                No players match "{@search_filter}"
                              </p>
                            </div>
                          <% end %>
                          <%= for app <- filtered_pool do %>
                            <% already_drafted = player_already_drafted?(@lineup, app.player_id) %>
                            <% layout = Map.fetch!(@formation_layouts, @formation) %>
                            <% slot_labels = InvinciblesWeb.GameLive.slot_labels(layout) %>
                            <% active_slots = [
                              :gk | layout.def ++ layout.amf ++ layout.mid ++ layout.fwd
                            ] %>
                            <% compatible_slots =
                              compatible_empty_slots(
                                @lineup,
                                app.player.primary_position,
                                active_slots
                              ) %>
                            <% unselectable = already_drafted or Enum.empty?(compatible_slots) %>
                            <div
                              draggable={if(unselectable, do: "false", else: "true")}
                              data-appearance-id={app.id}
                              data-positions={Enum.join(compatible_slots, ",")}
                              class={[
                                "group flex flex-col gap-1.5 px-3 py-2.5 rounded-lg border border-transparent transition-all duration-150",
                                if(unselectable,
                                  do: "opacity-40 cursor-not-allowed",
                                  else:
                                    "hover:bg-[#f9f9f9] hover:border-[rgba(0,0,0,0.08)] cursor-grab active:cursor-grabbing"
                                )
                              ]}
                            >
                              <%!-- Top row: name + club --%>
                              <div class="flex items-center gap-3">
                                <%!-- Player Info --%>
                                <div class="min-w-0 flex-1">
                                  <div class="font-semibold text-[13px] text-[rgba(0,0,0,0.87)] leading-tight">
                                    {app.player.name}
                                  </div>
                                  <div class="flex items-center gap-1.5 mt-0.5">
                                    <span class="text-[10px] font-bold text-[#00754A] uppercase tracking-[0.3px]">
                                      {app.player.primary_position}
                                    </span>
                                    <span class="text-[rgba(0,0,0,0.3)] text-[10px]">·</span>
                                    <span class="text-[rgba(0,0,0,0.45)] text-[10px] font-medium tracking-wide">
                                      {app.club.short_name}
                                    </span>
                                  </div>
                                </div>

                                <%!-- Drafted / Full badge --%>
                                <%= cond do %>
                                  <% already_drafted -> %>
                                    <span class="flex-shrink-0 text-[9px] font-semibold text-[rgba(0,0,0,0.38)] uppercase tracking-[0.4px]">
                                      Drafted
                                    </span>
                                  <% Enum.empty?(compatible_slots) -> %>
                                    <span class="flex-shrink-0 text-[9px] font-semibold text-[rgba(0,0,0,0.38)] uppercase tracking-[0.4px]">
                                      Full
                                    </span>
                                  <% true -> %>
                                    <%!-- nothing on the right side when slots are available --%>
                                <% end %>
                              </div>

                              <%!-- Slot buttons row (only when draftable) --%>
                              <%= if not already_drafted and not Enum.empty?(compatible_slots) do %>
                                <div class="flex flex-wrap gap-1 pl-11">
                                  <%= for slot <- compatible_slots do %>
                                    <button
                                      phx-click="draft_player"
                                      phx-value-appearance-id={app.id}
                                      phx-value-position-key={slot}
                                      class="bg-[#00754A] hover:bg-[#006241] active:scale-95 text-white font-bold text-[9px] px-2 py-0.5 rounded-full tracking-wider uppercase transition-all duration-100"
                                    >
                                      {elem(slot_labels[slot], 0)}
                                    </button>
                                  <% end %>
                                </div>
                              <% end %>
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  <% end %>

                  <%= if @step == :squad_complete do %>
                    <div class="text-center py-6">
                      <div class="w-12 h-12 mx-auto bg-[#edebe9] border border-[rgba(0,0,0,0.08)] rounded-[12px] flex items-center justify-center text-xl mb-4">
                        ⚽
                      </div>
                      <h2 class="text-lg font-bold tracking-tight mb-2 text-[#006241]">
                        Squad is Complete!
                      </h2>
                      <p class="text-xs text-[rgba(0,0,0,0.58)] leading-relaxed mb-6">
                        You have filled all 11 slots. Ready to simulate the 38-game season?
                      </p>
                      <button
                        phx-click="simulate_season"
                        class="w-full btn-starbucks btn-starbucks-filled text-sm"
                      >
                        START SIMULATION RUN
                      </button>
                    </div>
                  <% end %>

                  <%= if @step == :simulating do %>
                    <div>
                      <div class="flex items-center justify-between border-b border-[rgba(0,0,0,0.08)] pb-3 mb-4">
                        <span class="text-[11px] font-semibold text-[rgba(0,0,0,0.58)] uppercase tracking-[0.6px]">
                          Simulating Season
                          <%= if @sim_results && Map.get(@sim_results, :season_label) do %>
                            ({@sim_results.season_label})
                          <% end %>
                        </span>
                        <span class="text-[#00754A] text-[10px] font-bold uppercase tracking-[0.6px]">
                          LIVE MATCHDAY
                        </span>
                      </div>

                      <%!-- Simulation Matchday Logs --%>
                      <div class="flex flex-col gap-2 max-h-[300px] overflow-y-auto pr-1">
                        <%= for match <- Enum.reverse(@sim_results.matches) do %>
                          <%= if match.week < @season_record.week + 1 do %>
                            <.match_row match={match} />
                          <% end %>
                        <% end %>
                      </div>

                      <div class="mt-4 pt-4 border-t border-[rgba(0,0,0,0.08)] flex flex-col gap-2">
                        <div class="flex justify-between text-xs text-[rgba(0,0,0,0.58)]">
                          <span>Progress</span>
                          <span class="font-bold text-[rgba(0,0,0,0.87)]">
                            {@season_record.week} / 38 Gameweeks
                          </span>
                        </div>
                        <div class="w-full bg-[#edebe9] rounded-full h-1 overflow-hidden">
                          <div
                            class="bg-[#00754A] h-1 rounded-full transition-all duration-150"
                            style={"width: #{@season_record.week / 38 * 100}%"}
                          >
                          </div>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <%!-- Relocated Standings Card --%>
                <% pts = @season_record.wins * 3 + @season_record.draws
                gd = @season_record.gf - @season_record.ga
                gd_str = if gd >= 0, do: "+#{gd}", else: "#{gd}"
                is_invincible = @season_record.losses == 0
                is_perfect = @season_record.wins == 38
                funny_quote = get_funny_quote(@season_record)

                first_loss =
                  if @sim_results,
                    do: Enum.find(@sim_results.matches, &(&1.result == :loss)),
                    else: nil

                share_url = if @active_share, do: url(~p"/share/#{@active_share.id}"), else: nil %>

                <div
                  id="standings-table-card"
                  class="card-starbucks overflow-hidden flex flex-col shadow-md"
                >
                  <%!-- Header banner --%>
                  <div class={[
                    "rounded-t-xl px-6 py-4 flex items-center justify-between",
                    cond do
                      is_perfect -> "bg-gradient-to-r from-[#cba258] to-[#f0d47c]"
                      is_invincible -> "bg-gradient-to-r from-[#006241] to-[#00754A]"
                      true -> "bg-gradient-to-r from-[#1a1a1a] to-[#333]"
                    end
                  ]}>
                    <div>
                      <div class="text-[10px] font-bold uppercase tracking-[1.2px] text-white/70 mb-0.5">
                        {if @step == :hall_of_fame, do: "Golden Campaign", else: "Season Complete"}
                        <%= if @sim_results && Map.get(@sim_results, :season_label) do %>
                          · {@sim_results.season_label}
                        <% end %>
                      </div>
                      <div class="text-white font-black text-xl sm:text-2xl tracking-tight leading-none">
                        {cond do
                          is_perfect -> "PERFECT SEASON"
                          is_invincible -> "INVINCIBLES"
                          true -> "FINAL RECORD"
                        end}
                      </div>
                    </div>
                    <div class="text-right">
                      <div class="text-white/60 text-[10px] uppercase tracking-wider">Points</div>
                      <div class="text-white font-black text-2xl sm:text-3xl leading-none">{pts}</div>
                    </div>
                  </div>

                  <%!-- Stats pillars --%>
                  <div class="px-6 py-5 flex-1 flex flex-col gap-4">
                    <div class="grid grid-cols-5 gap-2 text-center">
                      <div class="flex flex-col gap-1">
                        <span class="text-lg sm:text-[22px] font-black text-[#006241] leading-none">
                          {@season_record.wins}
                        </span>
                        <span class="text-[9px] font-bold uppercase tracking-wider text-[rgba(0,0,0,0.4)]">
                          Won
                        </span>
                      </div>
                      <div class="flex flex-col gap-1">
                        <span class="text-lg sm:text-[22px] font-black text-[rgba(0,0,0,0.5)] leading-none">
                          {@season_record.draws}
                        </span>
                        <span class="text-[9px] font-bold uppercase tracking-wider text-[rgba(0,0,0,0.4)]">
                          Drawn
                        </span>
                      </div>
                      <div class="flex flex-col gap-1">
                        <span class={[
                          "text-lg sm:text-[22px] font-black leading-none",
                          if(@season_record.losses == 0, do: "text-[#006241]", else: "text-[#c82014]")
                        ]}>
                          {@season_record.losses}
                        </span>
                        <span class="text-[9px] font-bold uppercase tracking-wider text-[rgba(0,0,0,0.4)]">
                          Lost
                        </span>
                      </div>
                      <div class="flex flex-col gap-1">
                        <span class="text-lg sm:text-[22px] font-black text-[rgba(0,0,0,0.75)] leading-none">
                          {@season_record.gf}
                        </span>
                        <span class="text-[9px] font-bold uppercase tracking-wider text-[rgba(0,0,0,0.4)]">
                          GF
                        </span>
                      </div>
                      <div class="flex flex-col gap-1">
                        <span class={[
                          "text-lg sm:text-[22px] font-black leading-none",
                          if(gd >= 0, do: "text-[#00754A]", else: "text-[#c82014]")
                        ]}>
                          {gd_str}
                        </span>
                        <span class="text-[9px] font-bold uppercase tracking-wider text-[rgba(0,0,0,0.4)]">
                          GD
                        </span>
                      </div>
                    </div>

                    <%!-- First loss callout --%>
                    <%= if first_loss do %>
                      <div class="text-[11px] text-[rgba(0,0,0,0.6)] font-semibold text-center flex items-center justify-center gap-1.5 bg-[rgba(200,32,20,0.04)] border border-[rgba(200,32,20,0.08)] py-1.5 px-3 rounded-lg">
                        <span class="w-1.5 h-1.5 rounded-full bg-[#c82014] flex-shrink-0 animate-pulse">
                        </span>
                        <span>
                          First loss at GW {first_loss.week} — {first_loss.gf}–{first_loss.ga} vs {Map.get(
                            first_loss,
                            :opponent_short,
                            "OPP"
                          )}
                        </span>
                      </div>
                    <% end %>

                    <%!-- Funny quote --%>
                    <div class={[
                      "text-center text-xs sm:text-sm leading-relaxed italic px-2 my-2 py-3 border-y border-[rgba(0,0,0,0.05)]",
                      cond do
                        is_perfect -> "text-[#7a5c1e] font-semibold"
                        is_invincible -> "text-[#006241] font-semibold"
                        true -> "text-[rgba(0,0,0,0.78)] font-medium"
                      end
                    ]}>
                      "{funny_quote}"
                    </div>

                    <%!-- Play Again button --%>
                    <button
                      phx-click="start_game"
                      class="w-full btn-starbucks btn-starbucks-filled text-sm py-3 font-bold uppercase tracking-wider"
                    >
                      Play Again
                    </button>
                  </div>

                  <%!-- Footer actions --%>
                  <%= if share_url do %>
                    <div class="bg-[#f7f7f5] border-t border-[rgba(0,0,0,0.08)] px-5 py-4 flex flex-col gap-3">
                      <div class="flex items-center justify-between text-[10px] text-[rgba(0,0,0,0.5)] font-semibold uppercase tracking-[0.4px]">
                        <span>GA: {@season_record.ga} · Pts: {pts}</span>
                        <%= if @sim_results && Map.get(@sim_results, :season_label) do %>
                          <span>Season: {@sim_results.season_label}</span>
                        <% end %>
                      </div>
                      <div class="grid grid-cols-2 gap-2">
                        <button
                          id="share-twitter"
                          phx-hook="ShareButton"
                          data-wins={@season_record.wins}
                          data-draws={@season_record.draws}
                          data-losses={@season_record.losses}
                          data-points={pts}
                          data-season={
                            if @sim_results, do: Map.get(@sim_results, :season_label, ""), else: ""
                          }
                          data-quote={funny_quote}
                          data-share-url={share_url}
                          class="btn-starbucks btn-starbucks-black text-[10px] sm:text-xs py-2 px-2.5 flex items-center justify-center gap-1.5 whitespace-nowrap shadow-sm font-bold tracking-wider"
                        >
                          <svg class="w-3.5 h-3.5 fill-current text-white" viewBox="0 0 24 24">
                            <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
                          </svg>
                          SHARE TO TWITTER
                        </button>
                        <button
                          id="share-whatsapp"
                          phx-hook="WhatsAppShareButton"
                          data-wins={@season_record.wins}
                          data-draws={@season_record.draws}
                          data-losses={@season_record.losses}
                          data-points={pts}
                          data-season={
                            if @sim_results, do: Map.get(@sim_results, :season_label, ""), else: ""
                          }
                          data-quote={funny_quote}
                          data-share-url={share_url}
                          class="bg-[#25D366] hover:bg-[#20ba5a] text-white font-extrabold text-[10px] sm:text-xs py-2 px-2.5 rounded-[50px] transition-all flex items-center justify-center gap-1.5 whitespace-nowrap shadow-sm tracking-wider"
                        >
                          <svg class="w-3.5 h-3.5 fill-current text-white" viewBox="0 0 24 24">
                            <path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946C.06 5.348 5.397.01 12.008.01c3.202.001 6.212 1.246 8.477 3.514 2.266 2.268 3.507 5.28 3.505 8.484-.004 6.657-5.34 11.997-11.953 11.997-2.005-.001-3.973-.502-5.724-1.455L0 24zm6.59-4.846c1.6.95 3.488 1.459 5.407 1.461 5.432.003 9.85-4.413 9.854-9.847.002-2.63-1.023-5.101-2.887-6.969C17.159 1.932 14.686.907 12.06.907c-5.434 0-9.852 4.414-9.855 9.848-.002 1.81.472 3.58 1.375 5.143l-.975 3.565 3.65-.958zm10.742-5.403c-.3-.15-1.774-.875-2.046-.975-.272-.1-.471-.15-.669.15-.198.3-.765.976-.939 1.176-.173.199-.347.224-.648.075-1.037-.517-1.829-.916-2.543-1.52-.356-.302-.569-.646-.669-.896-.099-.25-.01-.385.088-.482.089-.088.199-.232.298-.348.099-.117.133-.199.199-.332.066-.133.033-.25-.017-.35-.05-.1-1.774-4.275-2.046-4.925-.265-.638-.535-.55-.669-.557l-.57-.008c-.198 0-.52.075-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.095 3.2 5.076 4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 1.774-.725 2.022-1.424.248-.699.248-1.299.174-1.424-.075-.125-.272-.199-.57-.349z" />
                          </svg>
                          SHARE TO WHATSAPP
                        </button>
                      </div>
                    </div>
                  <% end %>
                </div>

                <%!-- Match History (Desktop card) --%>
                <%= if @sim_results && @sim_results.matches != [] do %>
                  <div class="hidden lg:block card-starbucks p-6 flex flex-col gap-4">
                    <div class="flex items-center justify-between pb-3 border-b border-[rgba(0,0,0,0.08)]">
                      <span class="text-[11px] font-bold text-[rgba(0,0,0,0.4)] uppercase tracking-[0.6px]">
                        Match History
                      </span>
                    </div>
                    <div class="flex flex-col gap-2 max-h-[260px] overflow-y-auto pr-1">
                      <%= for match <- Enum.reverse(@sim_results.matches) do %>
                        <.match_row match={match} />
                      <% end %>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </main>

          <%= if @step == :squad_complete do %>
            <button
              phx-click="simulate_season"
              class="btn-frap transition-all duration-200"
              title="Simulate Season"
            >
              <.icon name="hero-play-solid" class="w-6 h-6 text-white" />
            </button>
          <% else %>
            <%= if @step == :spinning do %>
              <button
                phx-click="spin_wheel"
                class="btn-frap transition-all duration-200"
                title="Spin Wheel"
              >
                <.icon name="hero-arrow-path-solid" class="w-6 h-6 text-white" />
              </button>
            <% end %>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  def formation_layouts, do: @formation_layouts
end
