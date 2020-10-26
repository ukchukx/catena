defmodule CatenaApi.AuthControllerTest do
  alias Catena.Core.Utils

  use CatenaApi.ConnCase

  setup %{conn: conn} do
    user = Catena.new_user("test@email.com", "password")

    on_exit(fn ->
      Catena.stop()
    end)

    {:ok, conn: conn, user: user}
  end

  describe "signup/2" do
    test "succeeds with valid params", %{conn: conn} do
      email = "user@email.com"
      conn = post conn, Routes.auth_path(conn, :signup), %{email: email, password: "password"}
      json = json_response(conn, 201)

      assert json["success"]
      assert json["data"]["email"] == email
      assert Map.has_key?(json, "token")
    end

    test "fails when given an existing email", %{conn: conn, user: user} do
      conn = post conn, Routes.auth_path(conn, :signup), %{email: user.email, password: "password"}
      json = json_response(conn, 400)

      refute json["success"]
      refute Map.has_key?(json, "token")
      assert json["message"] == "Validation failed"
    end
  end

  describe "signin/2" do
    test "succeeds with valid params", %{conn: conn, user: %{email: email}} do
      conn = post conn, Routes.auth_path(conn, :signin), %{email: email, password: "password"}
      json = json_response(conn, 200)

      assert json["success"]
      assert json["data"]["email"] == email
      assert Map.has_key?(json, "token")
    end

    test "fails when given a non-existing email", %{conn: conn} do
      conn = post conn, Routes.auth_path(conn, :signin), %{email: "user@email.com", password: "password"}
      json = json_response(conn, 403)

      refute json["success"]
      refute Map.has_key?(json, "token")
      assert json["message"] == "Invalid email/password"
    end
  end

  describe "me/2" do
    test "succeeds when given a valid token", %{conn: conn, user: user} do
      conn = authenticated_conn(conn, user)
      conn = get conn, Routes.auth_path(conn, :me)
      json = json_response(conn, 200)

      assert json["success"]
      assert json["data"]["email"] == user.email
    end

    test "fails when not given a token", %{conn: conn} do
      conn = get conn, Routes.auth_path(conn, :me)
      assert json_response(conn, 401)
    end
  end

  describe "change_password/2" do
    test "succeeds when given the correct current password", %{conn: conn, user: user} do
      conn = authenticated_conn(conn, user)
      attrs = %{password: "password", new_password: "new_password"}
      conn = post conn, Routes.auth_path(conn, :change_password), attrs
      json = json_response(conn, 200)

      assert json["success"]
    end

    test "fails when not given an incorrect current password", %{conn: conn, user: user} do
      conn = authenticated_conn(conn, user)
      attrs = %{password: "new_password", new_password: "password"}
      conn = post conn, Routes.auth_path(conn, :change_password), attrs
      json = json_response(conn, 400)

      refute json["success"]
    end
  end

  describe "forgot/2" do
    test "succeeds when given an existing email", %{conn: conn, user: %{email: email}} do
      conn = post conn, Routes.auth_path(conn, :forgot), %{email: email}
      json = json_response(conn, 200)

      assert json["success"]
    end

    test "fails when not given an existing email", %{conn: conn} do
      email = "user@email.com"
      conn = post conn, Routes.auth_path(conn, :forgot), %{email: email}
      json = json_response(conn, 400)

      refute json["success"]
    end
  end

  describe "reset/2" do
    test "succeeds when given an existing reset token", %{conn: conn, user: %{email: email}} do
      token = Utils.random_string(20)
      password = "password1"
      Catena.save_reset(email, Utils.hash_password(token), 30)
      attrs = %{email: email, token: token, password: password}
      conn = post conn, Routes.auth_path(conn, :reset), attrs
      json = json_response(conn, 200)

      assert json["success"]
      assert Map.has_key?(json, "token")
      assert Map.has_key?(json, "data")
      assert {:ok, _} = Catena.authenticate_user(email, password)
    end

    test "fails when not given an existing reset token", %{conn: conn} do
      attrs = %{email: "user@email.com", token: Utils.random_string(20), password: "password"}
      conn = post conn, Routes.auth_path(conn, :reset), attrs
      json = json_response(conn, 400)

      refute json["success"]
    end
  end

end
