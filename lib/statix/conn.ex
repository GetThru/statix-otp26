defmodule Statix.Conn do
  @moduledoc false

  defstruct [:sock, :address, :port, :prefix, :socket_opts]

  alias Statix.Packet

  require Logger

  def new(host, port, prefix) when is_binary(host) do
    new(String.to_charlist(host), port, prefix)
  end

  def new(host, port, prefix) when is_list(host) or is_tuple(host) do
    case :inet.getaddr(host, :inet) do
      {:ok, address} ->
        %__MODULE__{address: address, port: port, prefix: prefix, socket_opts: [:inet]}

      {:error, _reason} ->
        # try with ipv6
        case :inet.getaddr(host, :inet6) do
          {:ok, address} ->
            %__MODULE__{address: address, port: port, prefix: prefix, socket_opts: [:inet6]}

          {:error, reason} ->
            raise(
              "cannot get the IP address for the provided host " <>
                "due to reason: #{:inet.format_error(reason)}"
            )
        end
    end
  end

  def open(%__MODULE__{} = conn) do
    opts = [active: false] ++ conn.socket_opts
    {:ok, sock} = :gen_udp.open(0, opts)
    %__MODULE__{conn | sock: sock}
  end

  def transmit(%__MODULE__{sock: sock, prefix: prefix} = conn, type, key, val, options)
      when is_binary(val) and is_list(options) do
    result =
      prefix
      |> Packet.build(type, key, val, options)
      |> transmit(conn)

    with {:error, error} <- result do
      Logger.error(fn ->
        if(is_atom(sock), do: "", else: "Statix ") <>
          "#{inspect(sock)} #{type} metric \"#{key}\" lost value #{val}" <>
          " error=#{inspect(error)}"
      end)
    end

    result
  end

  defp transmit(packet, %__MODULE__{address: address, port: port, sock: sock_name}) do
    sock = Process.whereis(sock_name)

    if sock do
      :gen_udp.send(sock, address, port, packet)
    else
      {:error, :port_closed}
    end
  end
end
