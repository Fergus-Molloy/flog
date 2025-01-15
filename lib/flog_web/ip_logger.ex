defmodule FlogWeb.IpLogger do
  def init(_), do: :ok

  def call(
        conn,
        _
      ) do
    log_file = System.get_env("IP_LOG_PATH", "/dev/null")
    write_ip_log(log_file, conn)

    conn
  end

  defp write_ip_log(
         file,
         %Plug.Conn{
           request_path: route,
           remote_ip: req_ip,
           method: verb,
           status: status
         } = conn
       ) do
    # respect x-forwarded-for
    ip =
      case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
        [] -> ip_to_bin(req_ip)
        [ip] -> ip
      end

    case File.write(
           file,
           "#{ip} - [#{DateTime.utc_now()}] - #{verb} #{route} #{status}\n",
           [:append]
         ) do
      {:error, reason} ->
        IO.puts("Error writing ip log to file #{file}, reason #{reason}")

      _ ->
        nil
    end
  end

  # ipv4
  defp ip_to_bin({_, _, _, _} = ip), do: Tuple.to_list(ip) |> Enum.join(".")

  # ipv6
  defp ip_to_bin({_, _, _, _, _, _, _, _} = ip), do: Tuple.to_list(ip) |> Enum.join(":")
end
