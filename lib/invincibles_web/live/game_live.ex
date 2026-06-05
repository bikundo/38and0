defmodule InvinciblesWeb.GameLive do
  use InvinciblesWeb, :live_view
  import InvinciblesWeb.Components.PlayerCard
  alias Invincibles.Game
  alias Invincibles.Game.SimEngine

  @positions_mapping %{
    "GK" => [:gk],
    "DF" => [:lb, :cb1, :cb2, :rb],
    "MF" => [:lm, :cm, :rm],
    "FW" => [:lw, :st, :rw]
  }

  @position_names %{
    gk: "GK",
    lb: "LB",
    cb1: "CB",
    cb2: "CB",
    rb: "RB",
    lm: "LM",
    cm: "CM",
    rm: "RM",
    lw: "LW",
    st: "ST",
    rw: "RW"
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
    |> assign(:lineup, %{
      gk: nil,
      lb: nil,
      cb1: nil,
      cb2: nil,
      rb: nil,
      lm: nil,
      cm: nil,
      rm: nil,
      lw: nil,
      st: nil,
      rw: nil
    })
    |> assign(:season_record, %{week: 0, wins: 0, draws: 0, losses: 0, gf: 0, ga: 0})
    |> assign(:sim_results, nil)
    |> assign(:simulating_week, nil)
    |> assign(:position_names, @position_names)
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    socket = reset_state(socket)
    eligible = get_eligible_positions(socket.assigns.lineup)

    case Game.spin_wheel(eligible) do
      {:ok, club, era, appearances} ->
        socket =
          socket
          |> assign(:current_spin, {club, era})
          |> assign(:draft_pool, appearances)
          |> assign(:step, :drafting)
          |> clear_flash()

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to load database players. Make sure the database is seeded.")}
    end
  end

  @impl true
  def handle_event("spin_wheel", _params, socket) do
    eligible = get_eligible_positions(socket.assigns.lineup)

    # Queries the database for 4 random appearances matching the selected Club & Era
    case Game.spin_wheel(eligible) do
      {:ok, club, era, appearances} ->
        socket =
          socket
          |> assign(:current_spin, {club, era})
          |> assign(:draft_pool, appearances)
          |> assign(:step, :drafting)
          |> clear_flash()

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to load database players. Make sure the database is seeded.")}
    end
  end

  @impl true
  def handle_event("draft_player", %{"appearance-id" => app_id, "position-key" => pos_key_str}, socket) do
    app_id = String.to_integer(app_id)
    pos_key = String.to_existing_atom(pos_key_str)
    appearance = Game.get_appearance(app_id)

    cond do
      not is_nil(Map.get(socket.assigns.lineup, pos_key)) ->
        {:noreply, put_flash(socket, :error, "Position slot already occupied!")}

      true ->
        # Update lineup
        new_lineup = Map.put(socket.assigns.lineup, pos_key, appearance)

        # Check if squad is complete (all 11 slots filled)
        squad_complete = Enum.all?(new_lineup, fn {_, val} -> not is_nil(val) end)

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
    total_weeks = socket.assigns.sim_results.week
    results = socket.assigns.sim_results

    if current_week <= total_weeks do
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
      # Simulation complete
      final_step =
        if results.wins == 38, do: :hall_of_fame, else: :game_over

      socket =
        socket
        |> assign(:step, final_step)

      {:noreply, socket}
    end
  end


  # Helper to get all eligible position groups that have empty slots in the lineup
  defp get_eligible_positions(lineup) do
    Enum.reduce(@positions_mapping, [], fn {pos_group, slots}, acc ->
      if Enum.any?(slots, &is_nil(Map.get(lineup, &1))) do
        [pos_group | acc]
      else
        acc
      end
    end)
  end

  # Helper to get the list of empty compatible slots for a player's primary position
  defp compatible_empty_slots(lineup, primary_position) do
    slots = Map.get(@positions_mapping, primary_position, [])
    Enum.filter(slots, &is_nil(Map.get(lineup, &1)))
  end


  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-950 text-slate-100 font-sans flex flex-col selection:bg-indigo-500 selection:text-white pb-12">
      <!-- Top Premium Navigation bar -->
      <header class="border-b border-slate-900 bg-slate-950/80 backdrop-blur-md sticky top-0 z-50">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <span class="text-2xl font-black bg-gradient-to-r from-amber-400 via-yellow-400 to-amber-600 bg-clip-text text-transparent tracking-tighter">
              INVINCIBLES
            </span>
            <span class="bg-indigo-500/10 border border-indigo-500/30 text-indigo-400 text-[10px] font-bold px-2 py-0.5 rounded uppercase tracking-wider">
              38-0-0 Retro Draft
            </span>
          </div>

          <div class="flex items-center gap-6">
            <div class="flex items-center gap-2.5">
              <div class="flex flex-col text-right">
                <span class="text-[10px] font-bold text-slate-500 uppercase tracking-widest leading-none">Record</span>
                <span class="text-sm font-extrabold tracking-wide text-slate-300 mt-0.5">
                  <%= @season_record.wins %>W - <%= @season_record.draws %>D - <%= @season_record.losses %>L
                </span>
              </div>
              <%= if @season_record.week > 0 do %>
                <span class="bg-slate-800 text-slate-300 text-xs font-black px-2 py-1 rounded">
                  W<%= @season_record.week %>
                </span>
              <% end %>
            </div>
          </div>
        </div>
      </header>

      <!-- Main container -->
      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-6 flex-1 grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        
        <!-- Left 8 columns: Game Board & Lineup Pitch -->
        <div class="lg:col-span-8 flex flex-col gap-6">
          <!-- Flash messages -->
          <%= if flash = Phoenix.Flash.get(@flash, :error) do %>
            <div class="bg-rose-500/10 border border-rose-500/30 text-rose-400 p-3 rounded-lg text-sm font-medium flex justify-between items-center animate-pulse">
              <span><%= flash %></span>
              <button phx-click="clear_flash" class="opacity-70 hover:opacity-100 font-bold">×</button>
            </div>
          <% end %>

          <!-- The Soccer Pitch Lineup View -->
          <div class="relative bg-gradient-to-b from-slate-900 to-slate-950 border border-slate-900 rounded-3xl p-6 overflow-hidden min-h-[600px] flex flex-col justify-between shadow-2xl">
            <!-- Grid pitch markings overlay -->
            <div class="absolute inset-0 opacity-10 pointer-events-none bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-indigo-500/20 via-transparent to-transparent"></div>
            <div class="absolute inset-x-0 top-1/2 h-[1px] bg-white/5 -translate-y-1/2 pointer-events-none"></div>
            <div class="absolute top-1/2 left-1/2 w-48 h-48 border border-white/5 rounded-full -translate-x-1/2 -translate-y-1/2 pointer-events-none"></div>
            <div class="absolute top-0 left-1/2 -translate-x-1/2 w-64 h-24 border-b border-x border-white/5 pointer-events-none"></div>
            <div class="absolute bottom-0 left-1/2 -translate-x-1/2 w-64 h-24 border-t border-x border-white/5 pointer-events-none"></div>

            <!-- Attacking Line (LW, ST, RW) -->
            <div class="flex justify-around items-center gap-2 z-10">
              <%= for pos <- [:lw, :st, :rw] do %>
                <div class="flex flex-col items-center">
                  <%= if card = @lineup[pos] do %>
                    <.player_card appearance={card} selected_pos={@position_names[pos]} />
                  <% else %>
                    <div class="w-28 h-40 rounded-xl border-2 border-dashed border-slate-800 bg-slate-950/40 flex flex-col items-center justify-center text-slate-600 gap-1 shadow-inner">
                      <span class="text-lg font-black tracking-wide text-slate-500"><%= @position_names[pos] %></span>
                      <span class="text-[9px] font-semibold opacity-60">EMPTY</span>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>

            <!-- Midfield Line (LM, CM, RM) -->
            <div class="flex justify-around items-center gap-2 z-10 my-6">
              <%= for pos <- [:lm, :cm, :rm] do %>
                <div class="flex flex-col items-center">
                  <%= if card = @lineup[pos] do %>
                    <.player_card appearance={card} selected_pos={@position_names[pos]} />
                  <% else %>
                    <div class="w-28 h-40 rounded-xl border-2 border-dashed border-slate-800 bg-slate-950/40 flex flex-col items-center justify-center text-slate-600 gap-1 shadow-inner">
                      <span class="text-lg font-black tracking-wide text-slate-500"><%= @position_names[pos] %></span>
                      <span class="text-[9px] font-semibold opacity-60">EMPTY</span>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>

            <!-- Defensive Line (LB, CB1, CB2, RB) -->
            <div class="flex justify-around items-center gap-2 z-10">
              <%= for pos <- [:lb, :cb1, :cb2, :rb] do %>
                <div class="flex flex-col items-center">
                  <%= if card = @lineup[pos] do %>
                    <.player_card appearance={card} selected_pos={@position_names[pos]} />
                  <% else %>
                    <div class="w-28 h-40 rounded-xl border-2 border-dashed border-slate-800 bg-slate-950/40 flex flex-col items-center justify-center text-slate-600 gap-1 shadow-inner">
                      <span class="text-lg font-black tracking-wide text-slate-500"><%= @position_names[pos] %></span>
                      <span class="text-[9px] font-semibold opacity-60">EMPTY</span>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>

            <!-- Goalkeeper (GK) -->
            <div class="flex justify-center items-center z-10 mt-6">
              <div class="flex flex-col items-center">
                <%= if card = @lineup[:gk] do %>
                  <.player_card appearance={card} selected_pos={@position_names[:gk]} />
                <% else %>
                  <div class="w-28 h-40 rounded-xl border-2 border-dashed border-slate-800 bg-slate-950/40 flex flex-col items-center justify-center text-slate-600 gap-1 shadow-inner">
                    <span class="text-lg font-black tracking-wide text-slate-500"><%= @position_names[:gk] %></span>
                    <span class="text-[9px] font-semibold opacity-60">EMPTY</span>
                  </div>
                <% end %>
              </div>
            </div>

          </div>
        </div>

        <!-- Right 4 columns: Game Controllers / Draft pool -->
        <div class="lg:col-span-4 flex flex-col gap-6">

          <!-- Game State Controller card -->
          <div class="bg-slate-900 border border-slate-900 rounded-3xl p-6 shadow-xl flex flex-col gap-5">
            
            <%= if @step == :not_started do %>
              <div class="text-center py-6">
                <div class="w-16 h-16 mx-auto bg-indigo-500/10 border border-indigo-500/30 rounded-full flex items-center justify-center text-2xl text-indigo-400 mb-4">
                  🏆
                </div>
                <h2 class="text-xl font-extrabold tracking-tight mb-2 text-slate-100">Can you build an Invincible squad?</h2>
                <p class="text-xs text-slate-400 leading-relaxed mb-6">
                  Draft an 11-man squad using historical Premier League players. Each draft spin gives you 4 random players matching a specific Club + Decade constraint. Try to win all 38 games to go down in history.
                </p>
                <button
                  phx-click="start_game"
                  class="w-full bg-gradient-to-r from-indigo-500 to-purple-600 hover:from-indigo-600 hover:to-purple-700 text-white font-extrabold py-3 px-4 rounded-xl shadow-lg shadow-indigo-500/20 active:scale-[0.98] transition-all"
                >
                  START DRAFT RUN
                </button>
              </div>
            <% end %>

            <%= if @step == :spinning do %>
              <div class="text-center py-6">
                <div class="w-16 h-16 mx-auto bg-amber-500/10 border border-amber-500/30 rounded-full flex items-center justify-center text-2xl text-amber-400 mb-4 animate-spin">
                  ⏳
                </div>
                <h2 class="text-xl font-extrabold tracking-tight mb-2 text-slate-100">Spin for your Constraints</h2>
                <p class="text-xs text-slate-400 leading-relaxed mb-6">
                  Spin the wheel to get a randomized combination of a Premier League Club and historical Era.
                </p>
                <button
                  phx-click="spin_wheel"
                  class="w-full bg-gradient-to-r from-amber-400 via-yellow-400 to-amber-600 hover:from-amber-500 hover:to-amber-700 text-slate-950 font-black py-3.5 px-4 rounded-xl shadow-lg shadow-yellow-500/10 active:scale-[0.98] transition-all"
                >
                  SPIN THE WHEEL
                </button>
              </div>
            <% end %>

            <%= if @step == :drafting do %>
              <div>
                <div class="flex items-center justify-between border-b border-slate-800 pb-3 mb-4">
                  <span class="text-xs font-black text-slate-400 uppercase tracking-wider">Current Constraints</span>
                  <span class="bg-indigo-500/20 text-indigo-400 text-[10px] font-extrabold px-2 py-0.5 rounded uppercase">Drafting</span>
                </div>
                
                <%= if @current_spin do %>
                  <% {club, era} = @current_spin %>
                  <div class="flex items-center justify-between bg-slate-950/60 border border-slate-800/80 rounded-xl p-3.5 shadow-inner mb-4">
                    <div class="flex items-center gap-2">
                      <span class="w-3.5 h-3.5 rounded-full" style={"background-color: #{club.primary_color};"}></span>
                      <span class="font-extrabold text-sm text-slate-200"><%= club.name %></span>
                    </div>
                    <span class="bg-slate-800 text-slate-200 text-xs font-black px-2.5 py-1 rounded">
                      <%= era %>
                    </span>
                  </div>
                <% end %>

                <h3 class="text-xs font-black text-slate-400 uppercase tracking-wider mb-3">Draft Pool Options</h3>
                
                <%= if Enum.empty?(@draft_pool) do %>
                  <div class="text-center py-6 bg-slate-950/40 rounded-xl border border-dashed border-slate-800">
                    <p class="text-xs text-slate-500 mb-4">No eligible historical players found for this Club + Era constraint.</p>
                    <button
                      phx-click="spin_wheel"
                      class="bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-bold px-4 py-2 rounded-lg"
                    >
                      SPIN AGAIN
                    </button>
                  </div>
                <% else %>
                  <div class="flex flex-col gap-4 max-h-[420px] overflow-y-auto pr-1">
                    <%= for app <- @draft_pool do %>
                      <div class="bg-slate-950/40 border border-slate-800/60 rounded-2xl p-3 flex gap-3 hover:border-slate-700 transition-colors">
                        <!-- Tiny Player Card Preview -->
                        <div class="flex-shrink-0">
                          <.player_card appearance={app} class="!w-24 !h-36 !p-2 !rounded-lg" />
                        </div>
                        
                        <!-- Draft Actions & Slot Matching -->
                        <div class="flex-1 flex flex-col justify-between py-0.5">
                          <div>
                            <h4 class="font-black text-sm text-slate-100 truncate"><%= app.player.display_name %></h4>
                            <p class="text-[10px] text-slate-500 font-medium mt-0.5"><%= app.player.primary_position %> | OVR <%= app.ovr %></p>
                          </div>

                          <div class="flex flex-wrap gap-1.5 mt-2">
                            <% compatible_slots = compatible_empty_slots(@lineup, app.player.primary_position) %>
                            <%= if Enum.empty?(compatible_slots) do %>
                              <span class="text-[9px] font-bold text-slate-500 bg-slate-800 px-2 py-1 rounded-md uppercase">
                                No Empty Slots
                              </span>
                            <% else %>
                              <%= for slot <- compatible_slots do %>
                                <button
                                  phx-click="draft_player"
                                  phx-value-appearance-id={app.id}
                                  phx-value-position-key={slot}
                                  class="bg-indigo-600 hover:bg-indigo-700 active:scale-95 text-white font-extrabold text-[9px] px-2 py-1 rounded shadow-sm tracking-wider uppercase transition-all"
                                >
                                  As <%= @position_names[slot] %>
                                </button>
                              <% end %>
                            <% end %>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>

              </div>
            <% end %>

            <%= if @step == :squad_complete do %>
              <div class="text-center py-6">
                <div class="w-16 h-16 mx-auto bg-emerald-500/10 border border-emerald-500/30 rounded-full flex items-center justify-center text-2xl text-emerald-400 mb-4 animate-bounce">
                  ⚽
                </div>
                <h2 class="text-xl font-extrabold tracking-tight mb-2 text-slate-100">Squad is Complete!</h2>
                <p class="text-xs text-slate-400 leading-relaxed mb-6">
                  You have filled all 11 slots and stayed within budget. Ready to simulate the 38-game season?
                </p>
                <button
                  phx-click="simulate_season"
                  class="w-full bg-gradient-to-r from-emerald-400 via-green-500 to-emerald-600 hover:from-emerald-500 hover:to-green-700 text-slate-950 font-black py-3.5 px-4 rounded-xl shadow-lg shadow-emerald-500/20 active:scale-[0.98] transition-all"
                >
                  START SIMULATION RUN
                </button>
              </div>
            <% end %>

            <%= if @step == :simulating do %>
              <div>
                <div class="flex items-center justify-between border-b border-slate-800 pb-3 mb-4">
                  <span class="text-xs font-black text-slate-400 uppercase tracking-wider">Simulating Season</span>
                  <span class="inline-flex items-center gap-1">
                    <span class="w-1.5 h-1.5 rounded-full bg-indigo-500 animate-ping"></span>
                    <span class="text-indigo-400 text-[10px] font-extrabold uppercase">Live Matchday</span>
                  </span>
                </div>

                <!-- Simulation Matchday Logs -->
                <div class="flex flex-col gap-2.5 max-h-[300px] overflow-y-auto pr-1">
                  <%= for match <- Enum.reverse(@sim_results.matches) do %>
                    <%= if match.week < @season_record.week + 1 do %>
                      <div class={"flex items-center justify-between border p-3 rounded-xl shadow-sm #{if match.result == :win, do: "bg-emerald-950/20 border-emerald-950/60 text-emerald-300", else: "bg-rose-950/20 border-rose-950/60 text-rose-300"}"}>
                        <div class="flex items-center gap-2">
                          <span class="text-xs font-black opacity-80">W<%= match.week %></span>
                          <span class="text-xs font-extrabold">INVINCIBLES <%= match.gf %> - <%= match.ga %> OPPONENT</span>
                        </div>
                        <span class="text-[9px] font-black uppercase tracking-widest px-2 py-0.5 rounded bg-black/20">
                          <%= match.result %>
                        </span>
                      </div>
                    <% end %>
                  <% end %>
                </div>

                <div class="mt-4 pt-4 border-t border-slate-800 flex flex-col gap-2">
                  <div class="flex justify-between text-xs text-slate-400">
                    <span>Progress</span>
                    <span class="font-extrabold"><%= @season_record.week %> / 38 Weeks</span>
                  </div>
                  <div class="w-full bg-slate-950 rounded-full h-1.5 overflow-hidden">
                    <div class="bg-indigo-500 h-1.5 rounded-full transition-all duration-150" style={"width: #{@season_record.week / 38 * 100}%"}></div>
                  </div>
                </div>

              </div>
            <% end %>

            <%= if @step == :game_over do %>
              <div class="text-center py-6">
                <div class="w-16 h-16 mx-auto bg-rose-500/10 border border-rose-500/30 rounded-full flex items-center justify-center text-2xl text-rose-400 mb-4">
                  ❌
                </div>
                <h2 class="text-xl font-extrabold tracking-tight mb-2 text-slate-100">Run Failed!</h2>
                <p class="text-xs text-slate-400 leading-relaxed mb-4">
                  Your Invincibles dream came to an end in <span class="font-extrabold text-slate-200">Week <%= @season_record.week %></span>. Any result other than a win immediately breaks the run.
                </p>

                <!-- Failed Match Summary -->
                <% last_match = List.last(@sim_results.matches) %>
                <%= if last_match do %>
                  <div class="bg-slate-950/80 border border-slate-850 rounded-xl p-3.5 text-center mb-6 shadow-inner">
                    <div class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">Failed Match (Week <%= last_match.week %>)</div>
                    <div class="text-lg font-black text-rose-400 mt-1">
                      INVINCIBLES <%= last_match.gf %> - <%= last_match.ga %> OPPONENT
                    </div>
                    <div class="text-[10px] text-slate-400 font-semibold mt-0.5 capitalize">Result: <%= last_match.result %></div>
                  </div>
                <% end %>

                <button
                  phx-click="start_game"
                  class="w-full bg-gradient-to-r from-indigo-500 to-purple-600 hover:from-indigo-600 hover:to-purple-700 text-white font-extrabold py-3 px-4 rounded-xl shadow-lg active:scale-[0.98] transition-all"
                >
                  TRY AGAIN
                </button>
              </div>
            <% end %>

            <%= if @step == :hall_of_fame do %>
              <div class="text-center py-6">
                <div class="w-20 h-20 mx-auto bg-amber-500/10 border border-amber-500/30 rounded-full flex items-center justify-center text-3xl text-amber-400 mb-4 animate-bounce">
                  👑
                </div>
                <h2 class="text-2xl font-black tracking-tight mb-2 bg-gradient-to-r from-amber-300 via-yellow-400 to-amber-600 bg-clip-text text-transparent">
                  GOLDEN TROPHY
                </h2>
                <p class="text-xs text-slate-300 font-extrabold tracking-wide mb-1">THE INVINCIBLES: 38-0-0</p>
                <p class="text-[10px] text-slate-400 leading-relaxed mb-6">
                  You have completed the perfect Premier League Retro Season! Your names are written in golden letters in the Hall of Fame.
                </p>

                <div class="bg-amber-950/20 border border-amber-800/40 rounded-xl p-4 text-center mb-6">
                  <div class="text-[10px] font-bold text-amber-500 uppercase tracking-widest">Final Record</div>
                  <div class="text-3xl font-black text-amber-300 mt-1">38 - 0 - 0</div>
                  <div class="text-[10px] text-amber-400 font-bold mt-1">
                    GF: <%= @season_record.gf %> | GA: <%= @season_record.ga %>
                  </div>
                </div>

                <button
                  phx-click="start_game"
                  class="w-full bg-gradient-to-r from-amber-400 via-yellow-400 to-amber-600 hover:from-amber-500 hover:to-amber-700 text-slate-950 font-black py-3.5 px-4 rounded-xl shadow-lg shadow-yellow-500/20 active:scale-[0.98] transition-all"
                >
                  PLAY ANOTHER RUN
                </button>
              </div>
            <% end %>

          </div>

          <!-- Squad Stats / Summary Panel -->
          <%= if @step != :not_started and @step != :spinning do %>
            <% strengths = SimEngine.calculate_strengths(@lineup) %>
            <div class="bg-slate-900 border border-slate-900 rounded-3xl p-6 shadow-xl flex flex-col gap-3">
              <h3 class="text-xs font-black text-slate-400 uppercase tracking-wider border-b border-slate-800 pb-2.5">Lineup Strengths</h3>
              
              <div class="flex flex-col gap-2">
                <div class="flex justify-between items-center text-xs">
                  <span class="text-slate-400">Attack Strength</span>
                  <span class="font-extrabold text-slate-200"><%= Float.round(strengths.attack, 1) %></span>
                </div>
                <div class="w-full bg-slate-950 rounded-full h-1 overflow-hidden">
                  <div class="bg-rose-500 h-1 rounded-full" style={"width: #{min(strengths.attack / 450 * 100, 100)}%"}></div>
                </div>

                <div class="flex justify-between items-center text-xs mt-1">
                  <span class="text-slate-400">Control Strength</span>
                  <span class="font-extrabold text-slate-200"><%= Float.round(strengths.control, 1) %></span>
                </div>
                <div class="w-full bg-slate-950 rounded-full h-1 overflow-hidden">
                  <div class="bg-indigo-500 h-1 rounded-full" style={"width: #{min(strengths.control / 650 * 100, 100)}%"}></div>
                </div>

                <div class="flex justify-between items-center text-xs mt-1">
                  <span class="text-slate-400">Defensive Strength</span>
                  <span class="font-extrabold text-slate-200"><%= Float.round(strengths.defense, 1) %></span>
                </div>
                <div class="w-full bg-slate-950 rounded-full h-1 overflow-hidden">
                  <div class="bg-emerald-500 h-1 rounded-full" style={"width: #{min(strengths.defense / 850 * 100, 100)}%"}></div>
                </div>

                <div class="flex justify-between items-center text-xs mt-1">
                  <span class="text-slate-400">Goalkeeping Strength</span>
                  <span class="font-extrabold text-slate-200"><%= Float.round(strengths.gk, 1) %></span>
                </div>
                <div class="w-full bg-slate-950 rounded-full h-1 overflow-hidden">
                  <div class="bg-amber-500 h-1 rounded-full" style={"width: #{min(strengths.gk / 99 * 100, 100)}%"}></div>
                </div>
              </div>
            </div>
          <% end %>

        </div>

      </main>
    </div>
    """
  end
end
