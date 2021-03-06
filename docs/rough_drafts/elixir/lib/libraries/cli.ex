defmodule Cli do
  defp lh do "localhost" end
  defp lp do Port.port end
	defp me do %Peer{port: lp, ip: lh} end
	def talk(msg, peer) do
		cond do
			is_list(peer) ->
				Tcp.get(peer[:ip], peer[:port], msg)
			true ->
				Tcp.get(peer.ip, peer.port, msg)
		end
	end
	def local_talk(msg, peer \\ me) do Tcp.get_local(peer.ip, peer.port+1000, msg) end
  def add_blocks(blocks, peer \\ me) do talk([:add_blocks, blocks], peer) end
  def txs(peer \\ me) do talk([:txs], peer) end
  def pushtx(tx, peer \\ me) do	talk([:pushtx, tx], peer) end
	def kv(key, peer \\ me) do talk([:kv, key], peer) end
  def fast_blocks(start, finish, peer \\ me) do
		#only use 1 network message. might not grab all blocks
		talk(["blocks", start, finish], peer)
	end
	def blocks(start, finish, peer \\ me, out \\ []) do
		more = fast_blocks(start+length(out), finish, peer)
    if more == [] do
      out
    else
      blocks(start, finish, peer, more ++ out)
    end
  end
  def add_peer(peer, pr \\ me) do talk([:add_peer, peer], pr)	end
  def all_peers(peer \\ me) do
		talk([:all_peers], peer) end
  def status(peer \\ me) do
		talk([:status], peer) end
  def buy_block(peer \\ me) do
		out = local_talk([:buy_block], peer)
		cleanup
		out
	end
	def cleanup do local_talk([:cleanup])	end
	def buy_blocks_helper(n) do
		1..n |> Enum.map(fn(_) ->
			local_talk([:buy_block])
			cleanup
			:timer.sleep(1000)
		end)
	end
  def buy_blocks(n) do spawn_link(fn -> buy_blocks_helper(n) end) end
  def spend(to, amount) do
		if is_binary(amount) do	amount = String.to_integer(amount) end
		local_talk([:spend, to, amount])
	end
	def to_channel(to, amount, peer \\ me) do
		if is_binary(amount) do amount = String.to_integer(amount) end
		local_talk([:to_channel, to, amount], peer)
	end
	def close_channel_fast(pub) do local_talk([:close_channel_fast, pub])	end
	def close_channel_slasher(tx) do local_talk([:close_channel_slasher, tx]) end
	def close_channel_timeout(key) do local_talk([:close_channel_timeout, key]) end
	def channel_spend(key, amount, peer \\ me) do local_talk([:channel_spend, key, amount], peer) end
	def channel_accept(tx, amount, peer \\ me) do talk([:accept, tx, amount],peer) end
	def channel_state(key) do local_talk([:channel_state, key]) end
	def new_key(brainwallet, p \\ me) do local_talk([:newkey, brainwallet], p) end
	def load_key(pub, priv, brainwallet) do local_talk([:loadkey, pub, priv, brainwallet]) end
	def unlock_key(brainwallet) do local_talk([:unlock, brainwallet]) end
	def change_password_key(current, new) do local_talk([:change_password_key, current, new]) end
	def lock_key do local_talk([:lock]) end
	def key_status do local_talk([:key_status]) end
	def sign(o, p \\ me) do local_talk([:sign, o], p) end
	def cost(peer \\ me) do talk(["cost"], peer) end
	def register(node, p \\ me) do local_talk([:register, node], p) end
	def delete_account(peer, p \\ me) do local_talk([:delete_account, peer], p) end
	def send_message(pub, msg, node, p \\ me) do local_talk([:send_message, node, pub, msg], p) end
	def read_message(index, pub, p \\ me) do local_talk([:read_message, index, pub], p) end
	def inbox_size(pub, p \\ me) do local_talk([:inbox_size, pub], p) end
	def delete_message(index, peer, p \\ me) do local_talk([:delete_message, index, peer], p) end
	def delete_all_messages(peer, p \\ me) do local_talk([:delete_all_messages, peer], p) end
	def inbox_peers(p \\ me) do local_talk([:inbox_peers], p) end
	def channel_balance(pub, p \\ me) do local_talk([:channel_balance, pub], p) end
	def channel_peers(p \\ me) do local_talk([:channel_peers], p) end
	def channel_get(pub, p \\ me) do local_talk([:channel_get, pub], p) end
	def mail_nodes(p \\ me) do talk([:mail_nodes], p) end
end
