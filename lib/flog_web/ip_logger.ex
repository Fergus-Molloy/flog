defmodule FlogWeb.IpLogger do
  def init(_) do
    # create log file and stuff here
    file_path =
      case Application.fetch_env!(:flog, FlogWeb.IpLogger) |> Keyword.get(:log_path) do
        nil -> "./flog.log"
        path -> path
      end

    file_path
  end

  defp get_file_for_writing(path) do
    if !File.exists?(path) do
      File.touch(path)
    end

    File.open!(path, [:binary, :append, :raw])
  end

  def call(
        conn,
        log_file
      ) do
    # will create file if it doesn't exist
    file = get_file_for_writing(log_file)

    write_ip_log(file, conn)

    File.close(file)

    conn
  end

  defp write_ip_log(
         file,
         %Plug.Conn{request_path: route, remote_ip: ip, method: verb, status: status}
       ) do
    case :file.write(
           file,
           "#{ip_to_bin(ip)} - [#{DateTime.utc_now()}] - #{verb} #{route} #{status}\n"
         ) do
      {:error, reason} ->
        IO.puts("Error writing ip log to file #{file}, reason #{reason}")

      _ ->
        nil
    end
  end

  # ipv4
  defp ip_to_bin({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"

  # ipv6
  defp ip_to_bin({0, 0, 0, 0, 0, f}), do: "::#{f}"
  defp ip_to_bin({0, 0, 0, 0, e, f}), do: "::#{e}:#{f}"
  defp ip_to_bin({0, 0, 0, d, e, f}), do: "::#{d}:#{e}:#{f}"
  defp ip_to_bin({0, 0, c, d, e, f}), do: "::#{c}:#{d}:#{e}:#{f}"
  defp ip_to_bin({0, b, c, d, e, f}), do: "::#{b}:#{c}:#{d}:#{e}:#{f}"
  defp ip_to_bin({a, b, c, d, e, f}), do: "#{a}:#{b}:#{c}:#{d}:#{e}:#{f}"
end
