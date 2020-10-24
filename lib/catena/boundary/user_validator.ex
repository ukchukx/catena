defmodule Catena.Boundary.UserValidator do
  import Catena.Boundary.Validator

  def errors(fields) when is_map(fields) do
    []
    |> require(fields, :email, &validate_email/1)
    |> optional(fields, :password, &validate_password/1)
  end

  def errors(_fields), do: [{nil, "A map of fields is required"}]

  def validate_email(email) when is_binary(email) do
    check(String.match?(email, ~r[\S+@\S+]), {:error, "is not an email address"})
  end

  def validate_email(_email), do: {:error, "must be a string"}

  def validate_password(password) when is_binary(password) do
    condition = String.match?(password, ~r[\S+]) && String.length(password) >= 6
    check(condition, {:error, "must be a string having >= 6 characters"})
  end

  def validate_password(_password), do: {:error, "must be a string"}
end
