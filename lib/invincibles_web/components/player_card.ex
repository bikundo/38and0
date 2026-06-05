defmodule InvinciblesWeb.Components.PlayerCard do
  use Phoenix.Component

  @doc """
  Renders an FC-style soccer player card.
  Expects:
  - `appearance`: The Appearance struct containing the player relation and stats.
  - `selected_pos`: (optional) Pos key if this card is currently placed in a lineup slot.
  - `cost`: (optional) The price of the player in transfer budget.
  """
  attr :appearance, :map, required: true
  attr :selected_pos, :string, default: nil
  attr :cost, :integer, default: nil
  attr :class, :string, default: ""
  attr :on_click, :any, default: nil
  attr :simple, :boolean, default: false

  def player_card(assigns) do
    # Calculate OVR and theme colors
    ovr = assigns.appearance.ovr
    player = assigns.appearance.player
    club = assigns.appearance.club

    assigns =
      assigns
      |> assign(:ovr, ovr)
      |> assign(:player, player)
      |> assign(:club, club)
      |> assign(:theme, get_card_theme(ovr))

    ~H"""
    <div
      phx-click={@on_click}
      class={[
        "relative w-48 h-72 rounded-xl flex flex-col justify-between p-4 select-none cursor-pointer transition-all duration-300 hover:scale-105 hover:-translate-y-1 active:scale-95 shadow-lg",
        @theme.bg_gradient,
        @theme.text_color,
        @theme.border_color,
        @class
      ]}
      style={@club && "border-left-width: 4px; border-left-color: #{@club.primary_color};"}
    >
      <!-- Glossy Reflection Overlay -->
      <div class="absolute inset-0 bg-gradient-to-tr from-white/0 via-white/10 to-white/20 rounded-xl pointer-events-none"></div>

      <%= if @simple do %>
        <!-- Simplified Card Content (for pitch) -->
        <div class="flex flex-col justify-between h-full w-full">
          <!-- Top: OVR and Position -->
          <div class="flex justify-between items-start">
            <div class="flex flex-col items-start">
              <span class="text-2xl font-black tracking-tight leading-none"><%= @ovr %></span>
              <span class="text-[9px] font-black uppercase tracking-wider opacity-90"><%= @player.primary_position %></span>
            </div>
            <!-- Club Dot Indicator -->
            <div class="w-3.5 h-3.5 rounded-full border border-black/10 shadow-sm" style={"background-color: #{@club.primary_color};"}></div>
          </div>

          <!-- Bottom: Last Name -->
          <div class="text-center mt-auto pb-1">
            <div class="text-[10px] font-black uppercase tracking-wide truncate max-w-full"><%= String.upcase(formatted_name(@player.display_name)) %></div>
            <%= if @selected_pos do %>
              <div class="text-[8px] font-bold opacity-80 mt-0.5"><%= @selected_pos %></div>
            <% end %>
          </div>
        </div>
      <% else %>
        <!-- Full Card Content -->
        <!-- Top Section: OVR and Position -->
        <div class="flex justify-between items-start">
          <div class="flex flex-col items-center">
            <span class="text-3xl font-extrabold tracking-tight leading-none"><%= @ovr %></span>
            <span class="text-xs font-bold uppercase tracking-wider opacity-80"><%= @player.primary_position %></span>
          </div>
          
          <div class="flex flex-col items-end text-right">
            <!-- Club primary color dot indicator and Short Name -->
            <div class="flex items-center gap-1.5 bg-black/10 px-1.5 py-0.5 rounded text-[10px] font-bold">
              <span class="w-2 h-2 rounded-full" style={"background-color: #{@club.primary_color};"}></span>
              <span><%= @club.short_name %></span>
            </div>
            <span class="text-[10px] font-bold tracking-wider mt-1 opacity-70"><%= @appearance.era %></span>
          </div>
        </div>

        <!-- Middle Section: Player Name and Season -->
        <div class="text-center my-2">
          <div class="text-xs font-semibold tracking-widest opacity-75"><%= @appearance.season %></div>
          <div class="text-lg font-black uppercase tracking-wide truncate max-w-full"><%= String.upcase(formatted_name(@player.display_name)) %></div>
        </div>

        <!-- Bottom Section: 3x2 Attribute Grid -->
        <div class="bg-black/5 rounded-lg p-2.5">
          <div class="grid grid-cols-3 gap-x-2 gap-y-1.5 text-center text-[10px]">
            <%= if @player.primary_position == "GK" do %>
              <!-- GK Stats -->
              <div>
                <div class="font-extrabold text-sm"><%= stat_value(@appearance.stats, "div") %></div>
                <div class="opacity-60 text-[8px] font-bold">DIV</div>
              </div>
              <div>
                <div class="font-extrabold text-sm"><%= stat_value(@appearance.stats, "han") %></div>
                <div class="opacity-60 text-[8px] font-bold">HAN</div>
              </div>
              <div>
                <div class="font-extrabold text-sm"><%= stat_value(@appearance.stats, "kic") %></div>
                <div class="opacity-60 text-[8px] font-bold">KIC</div>
              </div>
              <div>
                <div class="font-extrabold text-sm"><%= stat_value(@appearance.stats, "ref") %></div>
                <div class="opacity-60 text-[8px] font-bold">REF</div>
              </div>
              <div>
                <div class="font-extrabold text-sm"><%= stat_value(@appearance.stats, "spd") %></div>
                <div class="opacity-60 text-[8px] font-bold">SPD</div>
              </div>
              <div>
                <div class="font-extrabold text-sm"><%= stat_value(@appearance.stats, "pos") %></div>
                <div class="opacity-60 text-[8px] font-bold">POS</div>
              </div>
            <% else %>
              <!-- Outfield Stats -->
              <div>
                <div class="font-extrabold text-sm"><%= stat_value(@appearance.stats, "pac") %></div>
                <div class="opacity-60 text-[8px] font-bold">PAC</div>
              </div>
              <div>
                <div class="font-extrabold text-sm"><%= stat_value(@appearance.stats, "sho") %></div>
                <div class="opacity-60 text-[8px] font-bold">SHO</div>
              </div>
              <div>
                <div class="font-extrabold text-sm"><%= stat_value(@appearance.stats, "pas") %></div>
                <div class="opacity-60 text-[8px] font-bold">PAS</div>
              </div>
              <div>
                <div class="font-extrabold text-sm"><%= stat_value(@appearance.stats, "dri") %></div>
                <div class="opacity-60 text-[8px] font-bold">DRI</div>
              </div>
              <div>
                <div class="font-extrabold text-sm"><%= stat_value(@appearance.stats, "def") %></div>
                <div class="opacity-60 text-[8px] font-bold">DEF</div>
              </div>
              <div>
                <div class="font-extrabold text-sm"><%= stat_value(@appearance.stats, "phy") %></div>
                <div class="opacity-60 text-[8px] font-bold">PHY</div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Cost / Badge overlay if present -->
        <%= if @cost do %>
          <div class="absolute -bottom-3 left-1/2 -translate-x-1/2 bg-slate-900 text-emerald-400 border border-slate-700 text-[10px] font-bold px-2 py-0.5 rounded-full shadow-md z-10 whitespace-nowrap">
            £<%= format_cost(@cost) %>
          </div>
        <% end %>

        <%= if @selected_pos do %>
          <div class="absolute -top-2 -right-2 bg-indigo-600 text-white text-[9px] font-black uppercase px-2 py-0.5 rounded-full shadow border border-indigo-400 z-10">
            <%= @selected_pos %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  # Helpers to retrieve themes
  defp get_card_theme(ovr) do
    cond do
      ovr >= 90 ->
        %{
          bg_gradient: "bg-gradient-to-b from-amber-200 via-yellow-400 to-amber-700",
          text_color: "text-amber-950",
          border_color: "border border-amber-300 shadow-yellow-500/25"
        }

      ovr >= 83 ->
        %{
          bg_gradient: "bg-gradient-to-b from-yellow-50 via-yellow-200 to-yellow-500",
          text_color: "text-yellow-950",
          border_color: "border border-yellow-300/60 shadow-yellow-400/10"
        }

      true ->
        %{
          bg_gradient: "bg-gradient-to-b from-slate-200 via-slate-300 to-slate-500",
          text_color: "text-slate-950",
          border_color: "border border-slate-300 shadow-slate-500/10"
        }
    end
  end

  # Helper to retrieve "FirstInitial. LastName" from display name
  defp formatted_name(display_name) do
    case String.split(display_name, " ") do
      [_single] ->
        display_name
      [first | rest] ->
        initial = String.first(first)
        "#{initial}. #{Enum.join(rest, " ")}"
    end
  end

  # Helper to safely display stat values
  defp stat_value(stats, key) do
    Map.get(stats, key) || Map.get(stats, String.to_atom(key)) || 50
  end

  # Format cost to human readable format (e.g. 50M or 7.5M)
  defp format_cost(cost) do
    cond do
      cost >= 1_000_000 ->
        "#{Float.round(cost / 1_000_000, 1)}M"

      true ->
        "#{cost}"
    end
  end
end
