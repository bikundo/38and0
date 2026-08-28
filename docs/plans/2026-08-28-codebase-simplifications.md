# Codebase Simplifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the 7 architectural, data-structure, and control-flow simplifications identified in the codebase audit (R1–R7) to eliminate redundancy, streamline match simulation, normalize database record shapes, deduplicate pitch rendering, and clean up client-side share mechanics.

**Architecture:** Refactor the codebase across 4 logical layers: 1) SimEngine computational core unification, 2) Game context slot mapping & atom key normalization, 3) Shared presentation components (`PitchBoard`, `MatchRow`), and 4) Frontend JS share builder consolidation.

**Tech Stack:** Elixir, Phoenix LiveView 1.1, Tailwind CSS v4, Vanilla JS Hooks, ExUnit.

---

### Task 1: Unify Match Simulation in SimEngine (R1)

**Files:**
- Modify: `lib/invincibles/game/sim_engine.ex:124-173,438-471`
- Test: `test/invincibles/sim_engine_test.exs`

- [ ] **Step 1: Write test verifying `simulate_match/2` accepts custom opponent strengths and defaults to baseline**

Update `test/invincibles/sim_engine_test.exs`:

```elixir
  test "simulate_match/2 accepts custom opponent strengths", %{lineup: lineup} do
    strengths = SimEngine.calculate_strengths(lineup)
    opp_strengths = %{attack: 90.0, control: 90.0, defense: 90.0, gk: 90.0}

    {result, gf, ga} = SimEngine.simulate_match(strengths, opp_strengths)

    assert result in [:win, :draw, :loss]
    assert is_integer(gf)
    assert is_integer(ga)
  end
```

- [ ] **Step 2: Run test to verify it fails before implementation**

Run: `mix test test/invincibles/sim_engine_test.exs`
Expected: FAIL (function clause error or undefined `simulate_match/2`)

- [ ] **Step 3: Unify `simulate_match/2` in `SimEngine`**

In `lib/invincibles/game/sim_engine.ex`:
1. Change `simulate_match/1` definition to `simulate_match(user_strengths, opp_strengths \\ @opponent_baseline)`
2. Use `opp_strengths` inside the possession loop instead of hardcoded `@opponent_baseline`
3. Delete `simulate_match_against_opponent/2` (lines 438–471)
4. Replace `simulate_match_against_opponent(...)` call sites in `simulate_opponents_season` (lines 233, 308, 309) with `simulate_match(...)`

```elixir
  @doc """
  Simulates a single match between the User and an Opponent.
  Defaults opponent strengths to `@opponent_baseline`.
  Returns `{:win | :draw | :loss, user_goals, opp_goals}`.
  """
  def simulate_match(user_strengths, opp_strengths \\ @opponent_baseline) do
    {user_goals, opp_goals} =
      Enum.reduce(1..10, {0, 0}, fn _possession_index, {u_goals, o_goals} ->
        user_variance = 0.7 + :rand.uniform() * 0.6
        opp_variance = 0.7 + :rand.uniform() * 0.6

        user_control = user_strengths.control * user_variance
        opp_control = opp_strengths.control * opp_variance

        if user_control >= opp_control do
          if score_check?(
               user_strengths.attack,
               opp_strengths.defense,
               opp_strengths.gk
             ) do
            {u_goals + 1, o_goals}
          else
            {u_goals, o_goals}
          end
        else
          if score_check?(opp_strengths.attack, user_strengths.defense, user_strengths.gk) do
            {u_goals, o_goals + 1}
          else
            {u_goals, o_goals}
          end
        end
      end)

    result =
      cond do
        user_goals > opp_goals -> :win
        user_goals == opp_goals -> :draw
        true -> :loss
      end

    {result, user_goals, opp_goals}
  end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/invincibles/sim_engine_test.exs`
Expected: PASS (22 tests, 0 failures)

---

### Task 2: Standardize Season Accumulator and Match Accumulation in SimEngine (R2)

**Files:**
- Modify: `lib/invincibles/game/sim_engine.ex:187-255`
- Test: `test/invincibles/sim_engine_test.exs`

- [ ] **Step 1: Write test verifying match detail format in simulation results**

Add to `test/invincibles/sim_engine_test.exs`:

```elixir
  test "simulate_season/1 produces consistent match details format", %{lineup: lineup} do
    strengths = SimEngine.calculate_strengths(lineup)
    record = SimEngine.simulate_season(strengths)

    first_match = hd(record.matches)
    assert Map.has_key?(first_match, :week)
    assert Map.has_key?(first_match, :result)
    assert Map.has_key?(first_match, :gf)
    assert Map.has_key?(first_match, :ga)
    assert Map.has_key?(first_match, :opponent)
    assert Map.has_key?(first_match, :opponent_short)
  end
```

- [ ] **Step 2: Run test to verify existing behavior**

Run: `mix test test/invincibles/sim_engine_test.exs`

- [ ] **Step 3: Extract private helpers `new_season_accumulator/0` and `accumulate_match/3`**

In `lib/invincibles/game/sim_engine.ex`:

```elixir
  defp new_season_accumulator do
    %{week: 0, wins: 0, draws: 0, losses: 0, gf: 0, ga: 0, matches: []}
  end

  defp accumulate_match(acc, {result, gf, ga}, match_detail) do
    %{
      week: match_detail.week,
      wins: acc.wins + if(result == :win, do: 1, else: 0),
      draws: acc.draws + if(result == :draw, do: 1, else: 0),
      losses: acc.losses + if(result == :loss, do: 1, else: 0),
      gf: acc.gf + gf,
      ga: acc.ga + ga,
      matches: acc.matches ++ [match_detail]
    }
  end
```

Refactor `simulate_static_season/1` and `simulate_opponents_season/1`:

```elixir
  defp simulate_static_season(user_strengths) do
    Enum.reduce(1..38, new_season_accumulator(), fn week, acc ->
      outcome = {result, gf, ga} = simulate_match(user_strengths)

      match_detail = %{
        week: week,
        result: result,
        gf: gf,
        ga: ga,
        opponent: "Static Opponent",
        opponent_short: "OPP"
      }

      accumulate_match(acc, outcome, match_detail)
    end)
    |> Map.put(:season_label, "Simulation Mode")
  end
```

And in `simulate_opponents_season/1`:

```elixir
      our_matches =
        Enum.reduce(
          Enum.with_index(fixtures, 1),
          new_season_accumulator(),
          fn {opponent, index}, acc ->
            opp_strengths = Map.fetch!(opponent_strengths_map, opponent.id)
            outcome = {result, gf, ga} = simulate_match(user_strengths, opp_strengths)

            match_detail = %{
              week: index,
              result: result,
              gf: gf,
              ga: ga,
              opponent: opponent.name,
              opponent_short: opponent.short_name
            }

            accumulate_match(acc, outcome, match_detail)
          end
        )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/invincibles/sim_engine_test.exs`
Expected: PASS

---

### Task 3: Consolidate Slot to Position Category Mapping (R3)

**Files:**
- Modify: `lib/invincibles/game.ex:120-217`
- Test: `test/invincibles/game_test.exs`

- [ ] **Step 1: Write test for `auto_draft_lineup/2` across diverse slots**

Create `test/invincibles/game_test.exs`:

```elixir
defmodule Invincibles.GameTest do
  use Invincibles.DataCase
  alias Invincibles.Game
  alias Invincibles.Game.{Club, Player, Appearance}

  setup do
    club = Repo.insert!(%Club{name: "Draft FC", short_name: "DFC", primary_color: "#123"})

    players =
      for {name, pos} <- [
            {"GK Player", "GK"},
            {"LB Player", "DF"},
            {"CB1 Player", "DF"},
            {"CB2 Player", "DF"},
            {"CB3 Player", "DF"},
            {"RB Player", "DF"},
            {"LM Player", "MF"},
            {"CM Player", "MF"},
            {"RM Player", "MF"},
            {"LW Player", "FW"},
            {"ST Player", "FW"},
            {"RW Player", "FW"}
          ] do
        p = Repo.insert!(%Player{name: name, display_name: name, primary_position: pos})

        Repo.insert!(%Appearance{
          player: p,
          club: club,
          season: "2023-24",
          era: "20s",
          ovr: 85,
          stats: %{"pac" => 80, "sho" => 80, "pas" => 80, "dri" => 80, "def" => 80, "phy" => 80}
        })
      end

    {:ok, club: club, players: players}
  end

  test "auto_draft_lineup/2 fills all empty slots without error" do
    empty_lineup = %{
      gk: nil,
      lb: nil,
      cb1: nil,
      cb2: nil,
      cb3: nil,
      rb: nil,
      lm: nil,
      cm: nil,
      rm: nil,
      lw: nil,
      st: nil,
      rw: nil
    }

    active_slots = [:gk, :lb, :cb1, :cb2, :rb, :lm, :cm, :rm, :lw, :st, :rw]
    lineup = Game.auto_draft_lineup(empty_lineup, active_slots)

    for slot <- active_slots do
      assert %Appearance{} = Map.get(lineup, slot)
    end
  end
end
```

- [ ] **Step 2: Run test to verify baseline**

Run: `mix test test/invincibles/game_test.exs`

- [ ] **Step 3: Define `@slot_to_category` and replace `cond` blocks**

In `lib/invincibles/game.ex`:

```elixir
  @slot_to_category %{
    gk: "GK",
    lb: "DF",
    cb1: "DF",
    cb2: "DF",
    cb3: "DF",
    rb: "DF",
    lm: "MF",
    cm: "MF",
    cm1: "MF",
    cm2: "MF",
    cm3: "MF",
    rm: "MF",
    lw: "FW",
    st: "FW",
    st1: "FW",
    st2: "FW",
    rw: "FW"
  }
```

In `auto_draft_lineup/2`:

Replace line 153-160:
```elixir
      needed_categories =
        Enum.map(empty_slots, &Map.fetch!(@slot_to_category, &1))
        |> Enum.uniq()
```

Replace lines 178-184:
```elixir
        category = Map.fetch!(@slot_to_category, slot)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/invincibles/game_test.exs`
Expected: PASS

---

### Task 4: Normalize `season_record` Keys at Context Layer (R6)

**Files:**
- Modify: `lib/invincibles/game.ex:326-348`
- Modify: `lib/invincibles_web/live/game_live.ex:655-675`
- Modify: `lib/invincibles_web/live/share_live.ex:10-15`
- Test: `test/invincibles/game_share_test.exs`, `test/invincibles_web/live/leaderboard_test.exs`, `test/invincibles_web/live/share_live_test.exs`

- [ ] **Step 1: Write test verifying `list_active_shares/0` returns atomized keys in `season_record`**

In `test/invincibles/game_share_test.exs`, add:

```elixir
  test "list_active_shares/0 returns atom-keyed season_record" do
    {:ok, _share} =
      Game.create_share(
        %{gk: nil},
        "4-3-3",
        %{wins: 38, draws: 0, losses: 0, gf: 100, ga: 10, week: 38},
        "Season Record Test",
        "Quote"
      )

    shares = Game.list_active_shares()
    assert length(shares) >= 1
    sample = hd(shares)
    assert sample.season_record[:wins] == 38 or sample.season_record.wins == 38
    assert is_integer(sample.season_record.wins)
  end
```

- [ ] **Step 2: Run test to verify failure before atomization**

Run: `mix test test/invincibles/game_share_test.exs`

- [ ] **Step 3: Update `list_active_shares/0` in `lib/invincibles/game.ex`**

```elixir
  def list_active_shares do
    from(s in Share,
      order_by: [
        desc:
          fragment(
            "coalesce((?->>'wins')::integer, 0) * 3 + coalesce((?->>'draws')::integer, 0)",
            s.season_record,
            s.season_record
          ),
        asc: fragment("coalesce((?->>'losses')::integer, 0)", s.season_record),
        desc:
          fragment(
            "coalesce((?->>'gf')::integer, 0) - coalesce((?->>'ga')::integer, 0)",
            s.season_record,
            s.season_record
          ),
        desc: fragment("coalesce((?->>'wins')::integer, 0)", s.season_record),
        desc: s.inserted_at
      ],
      limit: 20
    )
    |> Repo.all()
    |> Enum.map(fn share ->
      season_record_atoms =
        Map.new(share.season_record, fn {k, v} -> {String.to_existing_atom(k), v} end)

      %{share | season_record: season_record_atoms}
    end)
  end
```

- [ ] **Step 4: Clean up dual-key access in `GameLive` and `ShareLive`**

In `lib/invincibles_web/live/game_live.ex` lines 655–672:
```elixir
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
```

In `lib/invincibles_web/live/share_live.ex` lines 10–15:
```elixir
        wins = share.season_record.wins
        draws = share.season_record.draws
        losses = share.season_record.losses
```

- [ ] **Step 5: Run tests to verify all pass**

Run: `mix test test/invincibles/game_share_test.exs test/invincibles_web/live/leaderboard_test.exs test/invincibles_web/live/share_live_test.exs`
Expected: PASS

---

### Task 5: Deduplicate Client-Side Share Text Assembly (R5)

**Files:**
- Modify: `assets/js/app.js:293-421`

- [ ] **Step 1: Extract `buildShareText` helper in `assets/js/app.js`**

Add helper function above `ShareButton`:

```javascript
const buildShareText = (el, url, { truncate = false } = {}) => {
  const wins = el.dataset.wins || "0";
  const draws = el.dataset.draws || "0";
  const losses = el.dataset.losses || "0";
  const points = el.dataset.points || "0";
  const season = el.dataset.season ? ` (${el.dataset.season})` : "";
  const quote = el.dataset.quote || "";

  const recordLine = `Record: ${wins}W - ${draws}D - ${losses}L | ${points} Pts${season} ⚽🏆`;
  const ctaLine = `Draft yours: ${url}`;
  const footer = `#InvinciblesDraft`;

  if (!quote) {
    return `${recordLine}\n${ctaLine}\n\n${footer}`;
  }

  const baseHeader = `\n\n${recordLine}\n${ctaLine}\n\n${footer}`;

  if (truncate) {
    const baseTwitterLength = getTwitterLength(baseHeader, url);
    const maxQuoteTwitterLength = 280 - baseTwitterLength - 2;

    if (maxQuoteTwitterLength > 3) {
      const quoteTwitterLength = getTwitterLength(quote);
      if (quoteTwitterLength > maxQuoteTwitterLength) {
        const targetLength = maxQuoteTwitterLength - 3;
        const truncated = truncateToTwitterLength(quote, targetLength);
        return `"${truncated}..."${baseHeader}`;
      }
      return `"${quote}"${baseHeader}`;
    }
    return `${recordLine}\n${ctaLine}\n\n${footer}`;
  }

  return `"${quote}"${baseHeader}`;
};
```

Update `ShareButton` and `WhatsAppShareButton`:

```javascript
  ShareButton: {
    mounted() {
      const openTwitter = (url) => {
        const text = buildShareText(this.el, url, { truncate: true });
        const tweetText = encodeURIComponent(text);
        window.open(`https://twitter.com/intent/tweet?text=${tweetText}`, "_blank");
      };

      this.el.addEventListener("click", () => {
        const directUrl = this.el.dataset.shareUrl;
        if (directUrl) {
          openTwitter(directUrl);
        } else {
          this.el.disabled = true;
          this._originalText = this.el.innerHTML;
          this.el.innerHTML = "Generating Link...";
          this.pushEvent("share_lineup", {});
        }
      });

      this.handleEvent("share_url", ({ url }) => {
        this.el.disabled = false;
        if (this._originalText) {
          this.el.innerHTML = this._originalText;
        }
        openTwitter(url);
      });
    }
  },

  WhatsAppShareButton: {
    mounted() {
      this.el.addEventListener("click", () => {
        const directUrl = this.el.dataset.shareUrl;
        if (!directUrl) return;

        const text = buildShareText(this.el, directUrl, { truncate: false });
        const whatsappUrl = `https://api.whatsapp.com/send?text=${encodeURIComponent(text)}`;
        window.open(whatsappUrl, "_blank");
      });
    }
  },
```

- [ ] **Step 2: Build assets and verify compilation**

Run: `mix assets.build`
Expected: PASS with 0 errors

---

### Task 6: Extract `match_row` Component in GameLive (R7)

**Files:**
- Modify: `lib/invincibles_web/live/game_live.ex`

- [ ] **Step 1: Define `match_row/1` function component in `GameLive`**

Add to `lib/invincibles_web/live/game_live.ex`:

```elixir
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
```

- [ ] **Step 2: Replace the 3 repeated match list blocks in `game_live.ex`**

1. Mobile match history:
```heex
                  <div class="flex flex-col gap-2 max-h-[300px] overflow-y-auto pr-1">
                    <%= for match <- Enum.reverse(@sim_results.matches) do %>
                      <.match_row match={match} />
                    <% end %>
                  </div>
```

2. Live simulation feed:
```heex
                      <div class="flex flex-col gap-2 max-h-[300px] overflow-y-auto pr-1">
                        <%= for match <- Enum.reverse(@sim_results.matches) do %>
                          <%= if match.week < @season_record.week + 1 do %>
                            <.match_row match={match} />
                          <% end %>
                        <% end %>
                      </div>
```

3. Desktop match history:
```heex
                    <div class="flex flex-col gap-2 max-h-[260px] overflow-y-auto pr-1">
                      <%= for match <- Enum.reverse(@sim_results.matches) do %>
                        <.match_row match={match} />
                      <% end %>
                    </div>
```

- [ ] **Step 3: Run tests to verify template compilation and rendering**

Run: `mix test`
Expected: PASS

---

### Task 7: Extract Shared `PitchBoard` Component and Remove Duplication (R4)

**Files:**
- Create: `lib/invincibles_web/components/pitch_board.ex`
- Modify: `lib/invincibles_web.ex:80-97`
- Modify: `lib/invincibles_web/live/game_live.ex:775-905,527-532`
- Modify: `lib/invincibles_web/live/share_live.ex:65-175,309-314`
- Test: `test/invincibles_web/live/share_live_test.exs`, `test/invincibles_web/live/leaderboard_test.exs`

- [ ] **Step 1: Create `lib/invincibles_web/components/pitch_board.ex`**

```elixir
defmodule InvinciblesWeb.Components.PitchBoard do
  use Phoenix.Component
  alias InvinciblesWeb.GameLive

  attr :lineup, :map, required: true
  attr :formation, :string, required: true
  attr :formation_layouts, :map, required: true
  attr :interactive, :boolean, default: false

  def pitch_board(assigns) do
    layout = Map.fetch!(assigns.formation_layouts, assigns.formation)
    slot_labels = GameLive.slot_labels(layout)

    assigns =
      assigns
      |> assign(:layout, layout)
      |> assign(:slot_labels, slot_labels)

    ~H"""
    <div
      id="game-pitch-container"
      class="relative bg-[#006241] border-4 border-[#1E3932] rounded-3xl p-6 overflow-hidden min-h-[660px] flex flex-col justify-between shadow-lg select-none"
    >
      <div class="absolute inset-4 border border-white/20 rounded-2xl pointer-events-none"></div>
      <div class="absolute inset-x-4 top-1/2 h-px bg-white/20 -translate-y-1/2 pointer-events-none"></div>
      <div class="absolute top-1/2 left-1/2 w-36 h-36 border border-white/20 rounded-full -translate-x-1/2 -translate-y-1/2 pointer-events-none"></div>
      <div class="absolute top-4 left-1/2 -translate-x-1/2 w-80 h-32 border-b border-x border-white/10 pointer-events-none"></div>
      <div class="absolute bottom-4 left-1/2 -translate-x-1/2 w-80 h-32 border-t border-x border-white/10 pointer-events-none"></div>

      <div class="flex justify-around items-center gap-2 z-10 mt-2">
        <%= for pos <- @layout.fwd do %>
          <.pitch_slot
            pos={pos}
            card={@lineup[pos]}
            label={elem(@slot_labels[pos], 0)}
            interactive={@interactive}
          />
        <% end %>
      </div>

      <%= if @layout.amf != [] do %>
        <div class="flex justify-around items-center gap-2 z-10 my-3">
          <%= for pos <- @layout.amf do %>
            <.pitch_slot
              pos={pos}
              card={@lineup[pos]}
              label={elem(@slot_labels[pos], 0)}
              interactive={@interactive}
            />
          <% end %>
        </div>
      <% end %>

      <div class="flex justify-around items-center gap-2 z-10 my-4">
        <%= for pos <- @layout.mid do %>
          <.pitch_slot
            pos={pos}
            card={@lineup[pos]}
            label={elem(@slot_labels[pos], 0)}
            interactive={@interactive}
          />
        <% end %>
      </div>

      <div class="flex justify-around items-center gap-2 z-10">
        <%= for pos <- @layout.def do %>
          <.pitch_slot
            pos={pos}
            card={@lineup[pos]}
            label={elem(@slot_labels[pos], 0)}
            interactive={@interactive}
          />
        <% end %>
      </div>

      <div class="flex justify-center items-center z-10 mb-2">
        <.pitch_slot
          pos={:gk}
          card={@lineup[:gk]}
          label={elem(@slot_labels[:gk], 0)}
          interactive={@interactive}
        />
      </div>
    </div>
    """
  end

  attr :pos, :atom, required: true
  attr :card, :map, default: nil
  attr :label, :string, required: true
  attr :interactive, :boolean, default: false

  defp pitch_slot(assigns) do
    ~H"""
    <div
      data-position-key={if @interactive, do: @pos, else: nil}
      class="pitch-slot flex flex-col items-center justify-center transition-all duration-200"
    >
      <%= if @card do %>
        <div class={[
          "w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#f43f5e] border-2 border-white/20 flex items-center justify-center text-white font-extrabold text-sm sm:text-base shadow-lg",
          if(@interactive,
            do: "cursor-grab active:cursor-grabbing hover:scale-105 transition-all",
            else: ""
          )
        ]}>
          {@label}
        </div>
        <div class="mt-2 px-2 py-1 bg-black/60 backdrop-blur-sm rounded-lg text-white text-[10px] sm:text-xs font-semibold shadow text-center whitespace-nowrap">
          {truncate_name(@card.player.display_name)}
        </div>
      <% else %>
        <div class="w-16 h-16 sm:w-20 sm:h-20 rounded-full border-2 border-dashed border-white/40 bg-black/20 backdrop-blur-sm flex items-center justify-center text-white/80 font-extrabold text-sm sm:text-base">
          {@label}
        </div>
      <% end %>
    </div>
    """
  end

  def truncate_name(name) do
    case String.split(name, " ") do
      [single] -> single
      parts -> List.last(parts)
    end
  end
end
```

- [ ] **Step 2: Import `PitchBoard` in `lib/invincibles_web.ex`**

In `lib/invincibles_web.ex` `html_helpers`:
```elixir
      import InvinciblesWeb.Components.PitchBoard
```

- [ ] **Step 3: Refactor `GameLive` and `ShareLive` to use `<.pitch_board>`**

In `lib/invincibles_web/live/game_live.ex`:
Replace pitch markup container (lines 777–903) with:
```heex
                <.pitch_board
                  lineup={@lineup}
                  formation={@formation}
                  formation_layouts={@formation_layouts}
                  interactive={true}
                />
```
Delete private `truncate_name/1` from `GameLive`.

In `lib/invincibles_web/live/share_live.ex`:
Replace pitch markup container (lines 66–175) with:
```heex
                <.pitch_board
                  lineup={@lineup}
                  formation={@formation}
                  formation_layouts={@formation_layouts}
                  interactive={false}
                />
```
Delete private `truncate_name/1` from `ShareLive`.

- [ ] **Step 4: Run full verification suite**

Run: `mix precommit`
Expected:
1. `compile --warning-as-errors`: 0 warnings, 0 errors
2. `deps.unlock --unused`: ok
3. `format`: clean
4. `test`: all tests passing (23+ tests)

---
