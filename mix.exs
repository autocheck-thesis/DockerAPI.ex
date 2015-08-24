defmodule DockerAPI.Mixfile do
  use Mix.Project

  def project do
    [
      app: :docker_api,
      version: "0.0.1",
      elixir: "~> 1.0",
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
    dev_apps = Mix.env == :dev && [:reprise] || []
    [applications: dev_apps ++ apps]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.8.4", only: :docs},
      {:earmark, "~> 0.1.17", only: :docs},
      {:reprise, "~> 0.3.0", only: :dev},
      {:poison , "~> 1.5.0"},
      {:httpoison, "~> 0.7.0"}
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
        "GitHub": "https://github.com/JonGretar/DockerAPI.ex",
        "Issues": "https://github.com/JonGretar/DockerAPI.ex/issues"
      }
    ]
  end
end
