defmodule CatenaApi.Token do
  use Joken.Config

  def token_config,
    do: default_claims(default_exp: Application.get_env(:catena_api, :token_ttl) * 60)

  def get_token(claims), do: CatenaApi.Token.generate_and_sign!(claims, signer())

  def signer do
    secret = Application.get_env(:catena_api, CatenaApi.Endpoint)[:secret_key_base]
    Joken.Signer.create("HS256", secret)
  end
end
