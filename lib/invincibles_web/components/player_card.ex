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
        "relative w-48 h-72 card-starbucks flex flex-col justify-between p-4 select-none cursor-pointer transition-all duration-300 hover:scale-105 hover:-translate-y-1 active:scale-95 border",
        @theme.bg_color,
        @theme.text_color,
        @theme.border_color,
        @class
      ]}
    >
      <%= if @simple do %>
        <div class="flex flex-col justify-between h-full w-full">
          <div class="flex justify-between items-start">
            <div class="flex flex-col items-start">
              <span class={[
                "text-2xl font-black tracking-tight leading-none font-serif-starbucks",
                @theme.ovr_color
              ]}>
                {@ovr}
              </span>
              <span class="text-[9px] font-black uppercase tracking-wider opacity-90 mt-0.5">
                {@player.primary_position}
              </span>
            </div>
            <div
              class="w-3.5 h-3.5 rounded-full border border-black/10 shadow-sm"
              style={"background-color: #{@club.primary_color};"}
            >
            </div>
          </div>

          <div class="text-center mt-auto pb-1 px-1">
            <div class="text-sm font-bold truncate max-w-full leading-normal py-0.5 font-script-starbucks text-slate-800">
              {formatted_name(@player.display_name)}
            </div>
            <%= if @selected_pos do %>
              <div class="text-[8px] font-bold opacity-80 mt-0.5 leading-none">{@selected_pos}</div>
            <% end %>
          </div>
        </div>
      <% else %>
        <div class="flex justify-between items-start">
          <div class="flex flex-col items-center">
            <span class={[
              "text-3xl font-black tracking-tight leading-none font-serif-starbucks",
              @theme.ovr_color
            ]}>
              {@ovr}
            </span>
            <span class="text-xs font-bold uppercase tracking-wider opacity-80 mt-0.5">
              {@player.primary_position}
            </span>
          </div>

          <div class="flex flex-col items-end text-right">
            <div class="flex items-center gap-1.5 bg-black/5 px-1.5 py-0.5 rounded text-[10px] font-bold">
              <span class="w-2 h-2 rounded-full" style={"background-color: #{@club.primary_color};"}>
              </span>
              <span>{@club.short_name}</span>
            </div>
            <span class="text-[10px] font-bold tracking-wider mt-1 opacity-70">
              {@appearance.era}
            </span>
          </div>
        </div>

        <div class="text-center my-2">
          <div class="text-[10px] font-semibold tracking-wider opacity-75">
            {String.upcase(@appearance.season)}
          </div>
          <div class="text-lg font-bold truncate max-w-full font-script-starbucks text-slate-800">
            {formatted_name(@player.display_name)}
          </div>
        </div>

        <div class="bg-black/5 rounded-lg p-2.5">
          <div class="grid grid-cols-3 gap-x-2 gap-y-1.5 text-center text-[10px]">
            <%= if @player.primary_position == "GK" do %>
              <div>
                <div class="font-bold text-sm">{stat_value(@appearance.stats, "div")}</div>
                <div class="text-[8px] font-semibold text-[rgba(0,0,0,0.58)]">DIV</div>
              </div>
              <div>
                <div class="font-bold text-sm">{stat_value(@appearance.stats, "han")}</div>
                <div class="text-[8px] font-semibold text-[rgba(0,0,0,0.58)]">HAN</div>
              </div>
              <div>
                <div class="font-bold text-sm">{stat_value(@appearance.stats, "kic")}</div>
                <div class="text-[8px] font-semibold text-[rgba(0,0,0,0.58)]">KIC</div>
              </div>
              <div>
                <div class="font-bold text-sm">{stat_value(@appearance.stats, "ref")}</div>
                <div class="text-[8px] font-semibold text-[rgba(0,0,0,0.58)]">REF</div>
              </div>
              <div>
                <div class="font-bold text-sm">{stat_value(@appearance.stats, "spd")}</div>
                <div class="text-[8px] font-semibold text-[rgba(0,0,0,0.58)]">SPD</div>
              </div>
              <div>
                <div class="font-bold text-sm">{stat_value(@appearance.stats, "pos")}</div>
                <div class="text-[8px] font-semibold text-[rgba(0,0,0,0.58)]">POS</div>
              </div>
            <% else %>
              <div>
                <div class="font-bold text-sm">{stat_value(@appearance.stats, "pac")}</div>
                <div class="text-[8px] font-semibold text-[rgba(0,0,0,0.58)]">PAC</div>
              </div>
              <div>
                <div class="font-bold text-sm">{stat_value(@appearance.stats, "sho")}</div>
                <div class="text-[8px] font-semibold text-[rgba(0,0,0,0.58)]">SHO</div>
              </div>
              <div>
                <div class="font-bold text-sm">{stat_value(@appearance.stats, "pas")}</div>
                <div class="text-[8px] font-semibold text-[rgba(0,0,0,0.58)]">PAS</div>
              </div>
              <div>
                <div class="font-bold text-sm">{stat_value(@appearance.stats, "dri")}</div>
                <div class="text-[8px] font-semibold text-[rgba(0,0,0,0.58)]">DRI</div>
              </div>
              <div>
                <div class="font-bold text-sm">{stat_value(@appearance.stats, "def")}</div>
                <div class="text-[8px] font-semibold text-[rgba(0,0,0,0.58)]">DEF</div>
              </div>
              <div>
                <div class="font-bold text-sm">{stat_value(@appearance.stats, "phy")}</div>
                <div class="text-[8px] font-semibold text-[rgba(0,0,0,0.58)]">PHY</div>
              </div>
            <% end %>
          </div>
        </div>

        <%= if @cost do %>
          <div class="absolute -bottom-3 left-1/2 -translate-x-1/2 bg-[#00754A] text-white border border-[#006241] text-[10px] font-bold px-2 py-0.5 rounded-full shadow-md z-10 whitespace-nowrap">
            £{format_cost(@cost)}
          </div>
        <% end %>

        <%= if @selected_pos do %>
          <div class="absolute -top-2 -right-2 bg-[#00754A] text-white text-[9px] font-black uppercase px-2 py-0.5 rounded-full shadow border border-[#006241] z-10">
            {@selected_pos}
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp get_card_theme(ovr) do
    cond do
      ovr >= 90 ->
        %{
          bg_color: "bg-white",
          text_color: "text-[rgba(0,0,0,0.87)]",
          border_color: "border-[#006241] border-2",
          ovr_color: "text-[#006241]"
        }

      ovr >= 83 ->
        %{
          bg_color: "bg-white",
          text_color: "text-[rgba(0,0,0,0.87)]",
          border_color: "border-[#00754A]",
          ovr_color: "text-[#00754A]"
        }

      true ->
        %{
          bg_color: "bg-white",
          text_color: "text-[rgba(0,0,0,0.87)]",
          border_color: "border-[rgba(0,0,0,0.12)]",
          ovr_color: "text-[rgba(0,0,0,0.58)]"
        }
    end
  end

  defp formatted_name(display_name) do
    case String.split(display_name, " ") do
      [single] ->
        single

      [first | rest] ->
        initial = String.first(first)
        "#{initial}. #{Enum.join(rest, " ")}"
    end
  end

  defp stat_value(stats, key) do
    Map.get(stats, key) || Map.get(stats, String.to_atom(key)) || 50
  end

  defp format_cost(cost) do
    cond do
      cost >= 1_000_000 ->
        "#{Float.round(cost / 1_000_000, 1)}M"

      true ->
        "#{cost}"
    end
  end
end
