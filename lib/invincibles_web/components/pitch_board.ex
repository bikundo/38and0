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
      <div class="absolute inset-x-4 top-1/2 h-px bg-white/20 -translate-y-1/2 pointer-events-none">
      </div>
      <div class="absolute top-1/2 left-1/2 w-36 h-36 border border-white/20 rounded-full -translate-x-1/2 -translate-y-1/2 pointer-events-none">
      </div>
      <div class="absolute top-4 left-1/2 -translate-x-1/2 w-80 h-32 border-b border-x border-white/10 pointer-events-none">
      </div>
      <div class="absolute bottom-4 left-1/2 -translate-x-1/2 w-80 h-32 border-t border-x border-white/10 pointer-events-none">
      </div>

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

  defp truncate_name(name) do
    case String.split(name, " ") do
      [single] -> single
      parts -> List.last(parts)
    end
  end
end
