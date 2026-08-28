defmodule InvinciblesWeb.SitemapXML do
  @moduledoc """
  XML rendering module for InvinciblesWeb.SitemapController.
  """

  def render("index.xml", %{squads: squads}) do
    xml_header = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    urlset_start = "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n"

    root_urls = """
      <url>
        <loc>https://invincibles.website/</loc>
        <changefreq>daily</changefreq>
        <priority>1.0</priority>
      </url>
      <url>
        <loc>https://invincibles.website/squads</loc>
        <changefreq>weekly</changefreq>
        <priority>0.9</priority>
      </url>
    """

    unique_clubs =
      squads
      |> Enum.map(fn {club_name, _} -> slugify(club_name) end)
      |> Enum.uniq()

    club_urls =
      Enum.map(unique_clubs, fn slug ->
        """
          <url>
            <loc>https://invincibles.website/squads/#{slug}</loc>
            <changefreq>weekly</changefreq>
            <priority>0.7</priority>
          </url>
        """
      end)
      |> Enum.join("")

    squad_urls =
      Enum.map(squads, fn {club_name, season} ->
        slug = slugify(club_name)

        """
          <url>
            <loc>https://invincibles.website/squads/#{slug}/#{season}</loc>
            <changefreq>monthly</changefreq>
            <priority>0.8</priority>
          </url>
        """
      end)
      |> Enum.join("")

    urlset_end = "</urlset>\n"

    Enum.join([xml_header, urlset_start, root_urls, club_urls, squad_urls, urlset_end])
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(" ", "-")
  end
end
