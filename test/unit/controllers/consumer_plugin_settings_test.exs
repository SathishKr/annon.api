defmodule Gateway.Controllers.ConsumerPluginSettingsTest do
  use Gateway.UnitCase

  setup do
    consumer = create_fixture(Gateway.DB.Schemas.Consumer)
    api      = create_fixture(Gateway.DB.Schemas.API)
    {:ok, plugin} = create_plugin(api.id, "acl")

    {:ok, %{external_id: consumer.external_id, api: api, plugin: plugin}}
  end

  test "GET /consumers/:external_id/plugins", %{external_id: external_id, api: api, plugin: plugin2} do
    {:ok, plugin1} = create_plugin(api.id, "idempotency")

    Gateway.DB.Schemas.ConsumerPluginSettings.create(external_id, %{plugin_id: plugin1.id})
    Gateway.DB.Schemas.ConsumerPluginSettings.create(external_id, %{plugin_id: plugin2.id})

    conn = :get
    |> conn("/#{external_id}/plugins")
    |> put_req_header("content-type", "application/json")
    |> Gateway.Controllers.Consumers.call([])

    result = Poison.decode!(conn.resp_body)["data"]
    assert 2 == Enum.count(result)
  end

  test "GET /consumers/:external_id/plugins/:name", %{external_id: external_id, plugin: plugin} do
    {:ok, cust_plugin1} = Gateway.DB.Schemas.ConsumerPluginSettings.create(external_id, %{plugin_id: plugin.id})

    conn = :get
    |> conn("/#{external_id}/plugins")
    |> put_req_header("content-type", "application/json")
    |> Gateway.Controllers.Consumers.call([])

    [result] = Poison.decode!(conn.resp_body)["data"]

    assert cust_plugin1.id == result["id"]
    assert cust_plugin1.external_id == result["external_id"]
    assert cust_plugin1.plugin_id == result["plugin_id"]
    assert cust_plugin1.settings == result["settings"]
    assert result["inserted_at"]
    assert result["updated_at"]
  end

  test "PUT /consumers/:external_id/plugins/:name", %{external_id: external_id, plugin: plugin} do
    params = %{plugin_id: plugin.id, settings: %{ "a" => 10, "b" => 20}}
    { :ok, cust_plugin1 } = Gateway.DB.Schemas.ConsumerPluginSettings.create(external_id, params)

    contents = %{
      settings: %{
        "a" => 1,
        "b" => 2
      }
    }

    conn = :put
    |> conn("/#{external_id}/plugins/#{plugin.name}", Poison.encode!(contents))
    |> put_req_header("content-type", "application/json")
    |> Gateway.Controllers.Consumers.call([])

    result =
      Poison.decode!(conn.resp_body)["data"]

    assert cust_plugin1.id == result["id"]
    assert cust_plugin1.external_id == result["external_id"]
    assert cust_plugin1.plugin_id == result["plugin_id"]
    assert contents[:settings] == result["settings"]
  end

  test "POST /consumers/:external_id/plugins", %{external_id: external_id, plugin: plugin} do
    contents = %{
      plugin_id: plugin.id,
      settings: %{
        "a" => 1,
        "b" => 2
      }
    }

    conn = :post
    |> conn("/#{external_id}/plugins", Poison.encode!(contents))
    |> put_req_header("content-type", "application/json")
    |> Gateway.Controllers.Consumers.call([])

    result = Poison.decode!(conn.resp_body)["data"]

    assert result["id"]
    assert external_id == result["external_id"]
    assert plugin.id == result["plugin_id"]
    assert contents[:settings] == result["settings"]
    assert result["inserted_at"]
    assert result["updated_at"]
  end

  test "DELETE /consumers/:external_id/plugins/:name", %{external_id: external_id, plugin: plugin} do
    params = %{plugin_id: plugin.id, settings: %{ "a" => 10, "b" => 20}}
    Gateway.DB.Schemas.ConsumerPluginSettings.create(external_id, params)

    conn = :delete
    |> conn("/#{external_id}/plugins/#{plugin.name}")
    |> put_req_header("content-type", "application/json")
    |> Gateway.Controllers.Consumers.call([])

    assert 200 == conn.status
  end

  defp create_fixture(module) do
    {:ok, entity} =
      module
      |> EctoFixtures.ecto_fixtures()
      |> module.create

    entity
  end

  defp create_plugin(api_id, plugin_name) do
    Gateway.DB.Schemas.Plugin.create(api_id, %{
      api_id: api_id,
      name: plugin_name,
      is_enabled: true,
      settings: %{"scope" => "read"}
    })
  end
end