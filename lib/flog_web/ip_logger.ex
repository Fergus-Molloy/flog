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

  # sobelow_skip ["Traversal"]
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
  defp ip_to_bin({_, _, _, _} = ip), do: Tuple.to_list(ip) |> Enum.join(".")

  # ipv6
  defp ip_to_bin({_, _, _, _, _, _, _, _} = ip), do: Tuple.to_list(ip) |> Enum.join(":")
end
