defmodule DockerAPI.Auth do
  defstruct username: "", password: "", email: "", auth: ""
  @type t :: %{username: String.t(), password: String.t(), email: String.t(), auth: String.t()}

  @doc """
  Generate a Base64 encoded auth header from a struct
  """
  @spec encode(DockerAPI.Auth.t()) :: String.t()
  def encode(auth) when is_map(auth) do
    auth |> Poison.encode!() |> Base.encode64()
  end

  @doc """
  Generate a Base64 encoded auth header from values
  """
  @spec encode(username :: String.t(), password :: String.t(), email :: String.t()) ::
          base64 :: String.t()
  def encode(username, password, email) do
    %DockerAPI.Auth{username: username, password: password, email: email}
    |> Poison.encode!()
    |> Base.encode64()
  end
end
