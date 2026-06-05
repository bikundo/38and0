defmodule InvinciblesWeb.ErrorJSONTest do
  use InvinciblesWeb.ConnCase, async: true

  test "renders 404" do
    assert InvinciblesWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert InvinciblesWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
