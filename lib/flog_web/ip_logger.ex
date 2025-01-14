defmodule FlogWeb.IpLogger do
  use Phoenix.VerifiedRoutes,
    endpoint: FlogWeb.Endpoint,
    router: FlogWeb.Router,
    statics: FlogWeb.static_paths()

  def init(_) do
    # create log file and stuff here
    file_path =
      case Application.fetch_env!(:flog, FlogWeb.IpLogger) |> Keyword.get(:log_path) do
        nil -> "./flog.log"
        path -> path
      end

    routes =
      Phoenix.Router.routes(FlogWeb.Router)
      |> Enum.map(fn %{path: route_path} ->
        String.split(route_path, ":", parts: 2) |> hd()
      end)

    {file_path, routes}
  end

  def call(
        %Plug.Conn{request_path: path, remote_ip: ip} = conn,
        {log_file, routes}
      ) do
    # will create file if it doesn't exist
    file = File.open!(log_file, [:append, :raw])

    matched_routes =
      routes
      |> Enum.filter(fn
        rp ->
          String.starts_with?(path, rp)
      end)

    if length(matched_routes) < 2 && path != "/" do
      IO.puts("route #{path} is valid? false")
      write_ip_log(file, ip, path)
    end

    IO.puts("route #{path} is valid? true")
    conn
  end

  defp write_ip_log(file, ip, route) do
    case :file.write(file, "[#{DateTime.utc_now()}] Req from #{ip_to_bin(ip)} for #{route}\n") do
      {:error, reason} ->
        IO.puts("Error writing ip log to file #{file}, reason #{reason}")

      _ ->
        nil
    end
  end

  defp ip_to_bin({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
end
