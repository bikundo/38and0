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

  @position_names %{
    gk: "GK",
    lb: "LB",
    cb1: "CB",
    cb2: "CB",
    cb3: "CB",
    rb: "RB",
    lm: "LM",
    cm: "CM",
    cm1: "CM",
    cm2: "CM",
    cm3: "CM",
    rm: "RM",
    lw: "LW",
    rw: "RW",
    st: "ST",
    st1: "ST",
    st2: "ST"
  }

  @position_descriptions %{
    gk: "Goalkeeper",
    lb: "Left",
    cb1: "Centre",
    cb2: "Centre",
    cb3: "Centre",
    rb: "Right",
    lm: "Left",
    cm: "Attacking",
    cm1: "Defensive",
    cm2: "Defensive",
    cm3: "Centre",
    rm: "Right",
    lw: "Left",
    rw: "Right",
    st: "Striker",
    st1: "Striker",
    st2: "Striker"
  }

  @formation_layouts %{
    "4-3-3" => %{
      def: [:lb, :cb1, :cb2, :rb],
      mid: [:lm, :cm, :rm],
      fwd: [:lw, :st, :rw]
    },
    "4-4-2" => %{
      def: [:lb, :cb1, :cb2, :rb],
      mid: [:lm, :cm1, :cm2, :rm],
      fwd: [:st1, :st2]
    },
    "3-5-2" => %{
      def: [:cb1, :cb2, :cb3],
      mid: [:lm, :cm1, :cm2, :cm3, :rm],
      fwd: [:st1, :st2]
    }
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, reset_state(socket)}
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
    |> assign(:position_names, @position_names)
    |> assign(:position_descriptions, @position_descriptions)
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
    active_slots = [:gk | layout.def ++ layout.mid ++ layout.fwd]
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
        # Update lineup
        new_lineup = Map.put(socket.assigns.lineup, pos_key, appearance)

        # Check if squad is complete (all active slots filled)
        layout = Map.fetch!(@formation_layouts, socket.assigns.formation)
        active_slots = [:gk | layout.def ++ layout.mid ++ layout.fwd]

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
        {:noreply, push_event(socket, "share_url", %{url: url})}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to generate share link.")}
    end
  end

  @impl true
  def handle_event("simulate_season", _params, socket) do
    # Calculate squad aggregates and run the simulator
    strengths = SimEngine.calculate_strengths(socket.assigns.lineup)
    results = SimEngine.simulate_season(strengths)

    # Start the animated simulation view
    socket =
      socket
      |> assign(:step, :simulating)
      |> assign(:sim_results, results)
      |> assign(:simulating_week, 1)

    # Trigger first week simulation step
    Process.send_after(self(), :tick_simulation, 150)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:tick_simulation, socket) do
    current_week = socket.assigns.simulating_week
    results = socket.assigns.sim_results

    if current_week <= 38 do
      # Calculate partial record up to current week
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
      # Full season complete — determine outcome
      final_step =
        cond do
          results.wins == 38 -> :hall_of_fame
          results.losses == 0 -> :hall_of_fame
          true -> :game_over
        end

      socket =
        socket
        |> assign(:step, final_step)

      {:noreply, socket}
    end
  end

  # Helper to get the list of empty compatible slots for a player's primary position within the active formation slots
  defp compatible_empty_slots(lineup, primary_position, active_slots) do
    slots = Map.get(@positions_mapping, primary_position, [])
    active_matching_slots = Enum.filter(slots, &Enum.member?(active_slots, &1))
    Enum.filter(active_matching_slots, &is_nil(Map.get(lineup, &1)))
  end

  # Helper to check if a player is already drafted in the lineup
  defp player_already_drafted?(lineup, player_id) do
    Enum.any?(lineup, fn {_, app} ->
      not is_nil(app) and app.player_id == player_id
    end)
  end

  defp truncate_name(name) do
    case String.split(name, " ") do
      [single] -> single
      parts -> List.last(parts)
    end
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} record={@season_record}>
      <div class="min-h-screen bg-[#f2f0eb] text-[rgba(0,0,0,0.87)] font-sans flex flex-col pb-12">
        <!-- Main container -->
        <main
          id="game-main-container"
          phx-hook="DragDropLineup"
          class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-6 flex-1 grid grid-cols-1 lg:grid-cols-12 gap-8 items-start w-full"
        >
          <!-- Left 8 columns: Game Board & Lineup Pitch -->
          <div class="order-2 lg:order-1 lg:col-span-8 flex flex-col gap-6">
            <!-- Share Capture Area enclosing Pitch + Record Details below it -->
            <div id="share-capture-area" class="bg-[#f2f0eb] flex flex-col gap-4">
              <!-- Soccer Pitch Lineup View -->
              <div
                id="game-pitch-container"
                class="relative bg-[#006241] border-4 border-[#1E3932] rounded-3xl p-6 overflow-hidden min-h-[660px] flex flex-col justify-between shadow-lg select-none"
              >
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
                
    <!-- Attacking Line -->
                <div class="flex justify-around items-center gap-2 z-10 mt-2">
                  <%= for pos <- layout.fwd do %>
                    <div
                      data-position-key={pos}
                      class="pitch-slot flex flex-col items-center justify-center transition-all duration-200"
                    >
                      <%= if card = @lineup[pos] do %>
                        <!-- Occupied Circle -->
                        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#f43f5e] border-2 border-white/20 flex items-center justify-center text-white font-extrabold text-sm sm:text-base shadow-lg cursor-grab active:cursor-grabbing hover:scale-105 transition-all">
                          {@position_names[pos]}
                        </div>
                        <div class="mt-2 px-2 py-1 bg-black/60 backdrop-blur-sm rounded-lg text-white text-[10px] sm:text-xs font-semibold shadow text-center whitespace-nowrap">
                          {truncate_name(card.player.display_name)}
                        </div>
                      <% else %>
                        <!-- Empty Circle -->
                        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full border-2 border-dashed border-white/40 bg-black/20 backdrop-blur-sm flex items-center justify-center text-white/80 font-extrabold text-sm sm:text-base">
                          {@position_names[pos]}
                        </div>
                        <div class="mt-2 px-3 py-0.5 bg-black/40 backdrop-blur-sm rounded-full text-white/80 text-[10px] sm:text-xs font-semibold tracking-wide">
                          {@position_descriptions[pos]}
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
                
    <!-- Midfield Line -->
                <div class="flex justify-around items-center gap-2 z-10 my-4">
                  <%= for pos <- layout.mid do %>
                    <div
                      data-position-key={pos}
                      class="pitch-slot flex flex-col items-center justify-center transition-all duration-200"
                    >
                      <%= if card = @lineup[pos] do %>
                        <!-- Occupied Circle -->
                        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#f43f5e] border-2 border-white/20 flex items-center justify-center text-white font-extrabold text-sm sm:text-base shadow-lg cursor-grab active:cursor-grabbing hover:scale-105 transition-all">
                          {@position_names[pos]}
                        </div>
                        <div class="mt-2 px-2 py-1 bg-black/60 backdrop-blur-sm rounded-lg text-white text-[10px] sm:text-xs font-semibold shadow text-center whitespace-nowrap">
                          {truncate_name(card.player.display_name)}
                        </div>
                      <% else %>
                        <!-- Empty Circle -->
                        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full border-2 border-dashed border-white/40 bg-black/20 backdrop-blur-sm flex items-center justify-center text-white/80 font-extrabold text-sm sm:text-base">
                          {@position_names[pos]}
                        </div>
                        <div class="mt-2 px-3 py-0.5 bg-black/40 backdrop-blur-sm rounded-full text-white/80 text-[10px] sm:text-xs font-semibold tracking-wide">
                          {@position_descriptions[pos]}
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
                
    <!-- Defensive Line -->
                <div class="flex justify-around items-center gap-2 z-10">
                  <%= for pos <- layout.def do %>
                    <div
                      data-position-key={pos}
                      class="pitch-slot flex flex-col items-center justify-center transition-all duration-200"
                    >
                      <%= if card = @lineup[pos] do %>
                        <!-- Occupied Circle -->
                        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#f43f5e] border-2 border-white/20 flex items-center justify-center text-white font-extrabold text-sm sm:text-base shadow-lg cursor-grab active:cursor-grabbing hover:scale-105 transition-all">
                          {@position_names[pos]}
                        </div>
                        <div class="mt-2 px-2 py-1 bg-black/60 backdrop-blur-sm rounded-lg text-white text-[10px] sm:text-xs font-semibold shadow text-center whitespace-nowrap">
                          {truncate_name(card.player.display_name)}
                        </div>
                      <% else %>
                        <!-- Empty Circle -->
                        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full border-2 border-dashed border-white/40 bg-black/20 backdrop-blur-sm flex items-center justify-center text-white/80 font-extrabold text-sm sm:text-base">
                          {@position_names[pos]}
                        </div>
                        <div class="mt-2 px-3 py-0.5 bg-black/40 backdrop-blur-sm rounded-full text-white/80 text-[10px] sm:text-xs font-semibold tracking-wide">
                          {@position_descriptions[pos]}
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
                
    <!-- Goalkeeper (GK) -->
                <div class="flex justify-center items-center z-10 mb-2">
                  <div
                    data-position-key="gk"
                    class="pitch-slot flex flex-col items-center justify-center transition-all duration-200"
                  >
                    <%= if card = @lineup[:gk] do %>
                      <!-- Occupied Circle -->
                      <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#f43f5e] border-2 border-white/20 flex items-center justify-center text-white font-extrabold text-sm sm:text-base shadow-lg cursor-grab active:cursor-grabbing hover:scale-105 transition-all">
                        {@position_names[:gk]}
                      </div>
                      <div class="mt-2 px-3 py-1 bg-black/60 backdrop-blur-sm rounded-lg text-white text-[10px] sm:text-xs font-semibold max-w-[80px] sm:max-w-[100px] truncate shadow">
                        {truncate_name(card.player.display_name)}
                      </div>
                    <% else %>
                      <!-- Empty Circle -->
                      <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full border-2 border-dashed border-white/40 bg-black/20 backdrop-blur-sm flex items-center justify-center text-white/80 font-extrabold text-sm sm:text-base">
                        {@position_names[:gk]}
                      </div>
                      <div class="mt-2 px-3 py-0.5 bg-black/40 backdrop-blur-sm rounded-full text-white/80 text-[10px] sm:text-xs font-semibold tracking-wide">
                        {@position_descriptions[:gk]}
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
              <!-- End share-capture-area -->

              <%= if @step in [:game_over, :hall_of_fame] do %>
                <% pts = @season_record.wins * 3 + @season_record.draws
                gd = @season_record.gf - @season_record.ga
                gd_str = if gd >= 0, do: "+#{gd}", else: "#{gd}"
                is_invincible = @season_record.losses == 0
                is_perfect = @season_record.wins == 38
                funny_quote = get_funny_quote(@season_record)
                first_loss = Enum.find(@sim_results.matches, &(&1.result == :loss)) %>
                <div id="standings-table-card">
                  <%!-- Header banner --%>
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
                        {if @step == :hall_of_fame, do: "Golden Campaign", else: "Season Complete"}
                        <%= if @sim_results && Map.get(@sim_results, :season_label) do %>
                          · {@sim_results.season_label}
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

                  <%!-- Stats pillars --%>
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

                    <%!-- First loss callout --%>
                    <%= if first_loss do %>
                      <div class="text-xs text-[rgba(0,0,0,0.6)] font-semibold text-center mt-4 mb-2 flex items-center justify-center gap-1.5">
                        <span class="w-1.5 h-1.5 rounded-full bg-[#c82014]"></span>
                        <span>
                          First loss at Week {first_loss.week} — {first_loss.gf}–{first_loss.ga} vs {Map.get(
                            first_loss,
                            :opponent_short,
                            "OPP"
                          )}
                        </span>
                      </div>
                    <% end %>

                    <%!-- Funny quote --%>
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
                      "{funny_quote}"
                    </div>
                  </div>

                  <%!-- Footer actions --%>
                  <div class="bg-[#f7f7f5] border border-[rgba(0,0,0,0.08)] rounded-b-xl px-6 py-4 flex items-center justify-between">
                    <span class="text-[10px] text-[rgba(0,0,0,0.4)]">
                      GA: {@season_record.ga} · Pts: {pts}
                    </span>
                    <button
                      id="share-btn"
                      phx-hook="ShareButton"
                      data-wins={@season_record.wins}
                      data-draws={@season_record.draws}
                      data-losses={@season_record.losses}
                      data-points={pts}
                      data-season={
                        if @sim_results, do: Map.get(@sim_results, :season_label, ""), else: ""
                      }
                      data-quote={funny_quote}
                      class="btn-starbucks btn-starbucks-black text-xs flex items-center gap-2"
                    >
                      <svg class="w-4 h-4 fill-current text-white" viewBox="0 0 24 24">
                        <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
                      </svg>
                      SHARE TO TWITTER
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
          <!-- End lg:col-span-8 -->
          
          <!-- Right 4 columns: Game Controllers / Draft pool -->
          <div class="order-1 lg:order-2 lg:col-span-4 flex flex-col gap-6">
            
    <!-- Game State Controller card -->
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
                    <div class="grid grid-cols-3 gap-2">
                      <%= for form_name <- ["4-3-3", "4-4-2", "3-5-2"] do %>
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
                      START DRAFT RUN
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
                      <.icon name="hero-magnifying-glass" class="w-3.5 h-3.5 text-[rgba(0,0,0,0.38)]" />
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
                            String.contains?(String.downcase(app.player.display_name), search_lower)
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
                        <% active_slots = [:gk | layout.def ++ layout.mid ++ layout.fwd] %>
                        <% compatible_slots =
                          compatible_empty_slots(@lineup, app.player.primary_position, active_slots) %>
                        <% unselectable = already_drafted or Enum.empty?(compatible_slots) %>
                        <div
                          draggable={if(unselectable, do: "false", else: "true")}
                          data-appearance-id={app.id}
                          data-positions={Enum.join(compatible_slots, ",")}
                          class={[
                            "group flex items-center justify-between gap-3 px-3 py-2 rounded-lg border border-transparent transition-all duration-150",
                            if(unselectable,
                              do: "opacity-40 cursor-not-allowed",
                              else:
                                "hover:bg-[#f9f9f9] hover:border-[rgba(0,0,0,0.08)] cursor-grab active:cursor-grabbing"
                            )
                          ]}
                        >
                          <div class="flex items-center gap-3 min-w-0">
                            <%!-- OVR Badge --%>
                            <div class="flex-shrink-0 w-8 h-8 rounded-lg bg-[#edebe9] border border-[rgba(0,0,0,0.08)] flex items-center justify-center font-bold text-xs text-[rgba(0,0,0,0.87)]">
                              {app.ovr}
                            </div>

                            <%!-- Player Info --%>
                            <div class="min-w-0">
                              <div class="font-bold text-[13px] text-[rgba(0,0,0,0.87)] truncate">
                                {app.player.display_name}
                              </div>
                              <div class="flex items-center gap-2 mt-0.5">
                                <span class="text-[9px] font-bold text-[#00754A] uppercase tracking-[0.4px]">
                                  {app.player.primary_position}
                                </span>
                                <span class="text-[rgba(0,0,0,0.58)] text-[9px] uppercase font-mono tracking-wider">
                                  {app.club.short_name}
                                </span>
                              </div>
                            </div>
                          </div>

                          <%!-- Draft Buttons --%>
                          <div class="flex-shrink-0 flex flex-wrap gap-1 justify-end">
                            <%= cond do %>
                              <% already_drafted -> %>
                                <span class="text-[9px] font-semibold text-[rgba(0,0,0,0.58)] uppercase tracking-[0.4px]">
                                  Drafted
                                </span>
                              <% Enum.empty?(compatible_slots) -> %>
                                <span class="text-[9px] font-semibold text-[rgba(0,0,0,0.58)] uppercase tracking-[0.4px]">
                                  Full
                                </span>
                              <% true -> %>
                                <%= for slot <- compatible_slots do %>
                                  <button
                                    phx-click="draft_player"
                                    phx-value-appearance-id={app.id}
                                    phx-value-position-key={slot}
                                    class="bg-[#00754A] hover:bg-[#006241] text-white font-bold text-[10px] px-2 py-1 rounded shadow-sm tracking-wider uppercase transition-colors"
                                  >
                                    {@position_names[slot]}
                                  </button>
                                <% end %>
                            <% end %>
                          </div>
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
                        <% result_badge_color =
                          cond do
                            match.result == :win -> "text-[#00754A]"
                            match.result == :draw -> "text-[#cba258]"
                            true -> "text-[#c82014]"
                          end %>
                        <div class="flex items-center justify-between border border-[rgba(0,0,0,0.08)] bg-white p-3 rounded-lg shadow-sm text-[rgba(0,0,0,0.87)]">
                          <div class="flex items-center gap-2">
                            <span class="text-xs font-semibold text-[rgba(0,0,0,0.58)]">
                              W{match.week}
                            </span>
                            <span class="text-xs font-semibold">
                              INVINCIBLES {match.gf} - {match.ga} {Map.get(
                                match,
                                :opponent_short,
                                "OPPONENT"
                              )}
                            </span>
                          </div>
                          <span class={[
                            "text-[9px] font-bold uppercase tracking-widest px-2 py-0.5 rounded bg-black/5",
                            result_badge_color
                          ]}>
                            {match.result}
                          </span>
                        </div>
                      <% end %>
                    <% end %>
                  </div>

                  <div class="mt-4 pt-4 border-t border-[rgba(0,0,0,0.08)] flex flex-col gap-2">
                    <div class="flex justify-between text-xs text-[rgba(0,0,0,0.58)]">
                      <span>Progress</span>
                      <span class="font-bold text-[rgba(0,0,0,0.87)]">
                        {@season_record.week} / 38 Weeks
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

              <%= if @step == :game_over do %>
                <div class="text-center py-6">
                  <div class="w-14 h-14 mx-auto bg-[#edebe9] border border-[rgba(0,0,0,0.08)] rounded-full flex items-center justify-center mb-4 shadow-sm">
                    <.icon name="hero-x-circle" class="w-6 h-6 text-[#c82014]" />
                  </div>
                  <h2 class="text-xl font-bold tracking-tight mb-2 text-[#006241]">
                    Season Complete
                  </h2>

                  <% total_losses = @season_record.losses %>
                  <p class="text-xs text-[rgba(0,0,0,0.58)] leading-relaxed mb-6">
                    <%= cond do %>
                      <% total_losses == 1 -> %>
                        Just 1 defeat all season! You were
                        <span class="font-semibold text-[#cba258]">agonizingly close</span>
                        to going unbeaten.
                      <% total_losses <= 3 -> %>
                        Only {total_losses} defeats. A
                        <span class="font-semibold text-[rgba(0,0,0,0.87)]">near-invincible</span>
                        campaign.
                      <% total_losses <= 8 -> %>
                        {total_losses} defeats — a solid season, but the Invincibles dream needs more.
                      <% true -> %>
                        {total_losses} defeats. Your squad needs reinforcements!
                    <% end %>
                  </p>

                  <button
                    phx-click="start_game"
                    class="w-full btn-starbucks btn-starbucks-filled text-sm"
                  >
                    Try Again
                  </button>
                </div>
              <% end %>

              <%= if @step == :hall_of_fame do %>
                <div class="text-center py-6">
                  <div class="w-14 h-14 mx-auto bg-[#faf6ee] border border-[#dfc49d] rounded-full flex items-center justify-center mb-4 shadow-sm">
                    <.icon name="hero-star" class="w-6 h-6 text-[#cba258]" />
                  </div>
                  <h2 class="text-xl font-bold tracking-tight mb-2 text-[#cba258]">
                    {if @season_record.wins == 38, do: "Golden Trophy", else: "The Unbeaten"}
                  </h2>
                  <p class="text-xs text-[rgba(0,0,0,0.58)] leading-relaxed mb-6">
                    <%= if @season_record.wins == 38 do %>
                      A perfect 38-0-0! Every single game won. Your names are written in golden letters in the Hall of Fame.
                    <% else %>
                      You went the entire season unbeaten! A legendary campaign worthy of the history books.
                    <% end %>
                  </p>

                  <button
                    phx-click="start_game"
                    class="w-full btn-starbucks btn-starbucks-filled text-sm"
                  >
                    Play Another Run
                  </button>
                </div>
              <% end %>
            </div>
          </div>
        </main>
        
    <!-- Frap Floating CTA Button -->
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
      </div>
    </Layouts.app>
    """
  end

  def formation_layouts, do: @formation_layouts
end
