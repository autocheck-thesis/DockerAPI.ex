defmodule DockerAPI.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_dockerapi,
      version: "0.0.1",
      elixir: "~> 1.5",
      deps: deps,
      description: description,
      package: package,
      docs: [readme: "Readme.md", main: DockerAPI],
      name: "DockerAPI",
      source_url: "https://github.com/JonGretar/DockerAPI.ex",
      homepage_url: "https://github.com/JonGretar/DockerAPI.ex"
    ]
  end

  def application do
    apps = [:logger, :httpoison]
    [applications: apps]
  end

  defp deps do
    [
      {:poison, "~> 4.0"},
      {:httpoison, "~> 1.4"}
    ]
  end

  defp description do
    """
    Docker API client.
    """
  end

  defp package do
    [
      contributors: ["Jón Grétar Borgþórsson"],
      licenses: ["MIT"],
      links: %{
        GitHub: "https://github.com/JonGretar/DockerAPI.ex",
        Issues: "https://github.com/JonGretar/DockerAPI.ex/issues"
      }
    ]
  end
end
