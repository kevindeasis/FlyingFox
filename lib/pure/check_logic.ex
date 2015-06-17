defmodule CheckLogic do
	def bond2spend(_, _) do true end
	def spend(tx, txs) do
    block = tx.data
    fee = block.fee
    amount = block.amount
    cond do
      fee < Constants.min_tx_fee ->
        IO.puts("fee too low")
        false
      amount+fee > Constants.max_bond ->
        IO.puts("too much money at once")
        false
      true -> true
    end		
	end
	def spend2wait(tx, txs) do
    pub = tx.pub
    acc = KV.get(pub)
    cond do
      {0,0} != acc.wait -> false
      true -> true
    end		
	end
	def wait2bond(tx, txs) do
		acc = KV.get(tx.pub)
    {a, h} = tx.data.wait_money
    cond do
      {a, h} != acc.wait -> false 
      h > KV.get("height") + Constants.epoch -> false 
      true -> true
    end
	end
	def bond2spend(tx, txs) do
	end
	def slasher(tx, txs) do
		old_block = Blockchain.get_block(tx.data.signed_on)
    tx1 = tx.data.tx1
    tx2 = tx.data.tx2
    cond do
      tx.data.tx1.pub in old_block.meta.revealed ->
        IO.puts "slasher reuse"
        false
      tx1.data.prev_hash == tx2.data.prev_hash ->
        IO.puts("same tx_hash")
        false
      tx1.data.height != tx2.data.height ->
        IO.puts("different height")
        false
      not Sign.verify_tx(tx1) ->
        IO.puts("unsigned")
        false
      not Sign.verify_tx(tx2) ->
        IO.puts("unsigned 2")
        false
    end
    #If you can prove that the same address signed on 2 different blocks at the same height, then you can take 1/3rd of the deposit, and destroy the rest.
	end
	def reveal(tx, txs) do
    old_block = Blockchain.get_block(tx.data.signed_on)
    revealed = txs
    |> Enum.filter(&(&1.data.type == "reveal"))
    |> Enum.filter(&(&1.pub == tx.pub))
    signed = old_block.data.txs |> Enum.filter(&(&1.pub == tx.pub))  |> Enum.filter(&(&1.data.__struct__ == :Elixir.SignTx))
    bond_size = old_block.data.bond_size
    blen = bond_size*length(tx.data.winners)
    amount = tx.data.amount
    cond do
      length(revealed) > 0 -> false
      length(signed) == 0 ->
        IO.puts "0"
        false
      byte_size(tx.data.secret) != 10 ->
        IO.puts "1"
        false
      DetHash.doit(tx.data.secret) != hd(signed).data.secret_hash ->
        IO.puts "2"
        false
      tx.pub in old_block.meta.revealed ->
        IO.puts "3"
        false
      amount != blen ->
        IO.puts "4 slfjksd"
        false
      KV.get("height") - Constants.epoch > tx.data.signed_on ->
        IO.puts "5"
        false
      true -> true
    end
    #After you sign, you wait a while, and eventually are able to make this tx. 
    #This tx reveals the random entropy_bit and salt from the sign tx, and it reclaims 
    #the safety deposit given in the sign tx. If your bit is in the minority, then your prize is bigger.
	end
	def to_channel(tx, txs) do
    channel = KV.get(tx.data.pub<>tx.data.pub2)
    cond do
      not tx.data.to in [:pub, :pub2] -> false
      (channel == nil) and (tx.data.new != true) -> false
      (channel != nil) and (tx.data.new == true) -> false
      true -> true
    end
		#dont allow this any more after a channel_block has been published, or if there is a channel_block tx in the mempool.
	end
	def channel_block(tx, txs) do
    da = tx.data
    channel = KV.get(da.channel)
		b = tx.bets |> Enum.map(fn(x) -> x.amount end)
		c = b |> Enum.reduce(0, &(&1+&2))
		bool = b |> Enum.map(fn(x) -> x >= 0 end) |> Enum.reduce(&(&1 and &2))
    cond do
			not bool ->
				IO.puts("no negative money")
				false
      not VerifyTx.check_sig2(tx) -> false
      da.amount + da.amount2 + c > channel[da.pub] + channel[da.pub2] ->
				IO.puts("no counterfeiting")
				false
      da.secret_hash != nil and da.secret_hash != DetHash.doit(tx.meta.secret) ->
				IO.puts("secret does not match")
				false
      true -> true
    end
		#must contain the entire current state of the channel.
		#fee can be paid by either or both.

	end
	def close_channel(tx, txs) do
    #only one per block per channel. be careful.
    channel = KV.get(tx.data.channel)
    case tx.data.type do
      "fast"    -> if VerifyTx.check_sig2(tx) do ChannelBlock.check(tx, txs) end
      "slash"   -> if channel.nonce < tx.data.nonce do ChannelBlock.check(tx, txs) end
      "timeout" -> channel.time < KV.get("height") - channel.delay
    end
	end
	def oracle(tx, txs) do
		#can the creator afford this?
		#no Sztorc at first.
		#what are the addresses?
		#How many addresses are needed?
		n = length(tx.data.participants)
		cond do
			n > tx.data.m -> false
			tx.data.m < 1 -> false
			true -> true
		end

	end
	def judgement(tx, txs) do
		false
	end
	def win(tx, txs) do
		false
	end
	def first_bits(b, s) do
		<< c :: size(s), _ :: bitstring >> = b
		s = s + 8 - rem(s, 8) #so that we have an integer number of bytes.
		<< c :: size(s) >>
	end
	def ran_block(block) do
		txs = block.data.txs
		cond do
			is_nil(txs) -> 0
			true ->
				txs |> Enum.filter(&(&1.data.__struct__=="reveal"))
				|> Enum.map(&(first_bits(&1.data.secret, length(&1.data.winners))))
				|> Enum.reduce("", &(&1 <> &2))
		end
	end
	def rng(hash, counter \\ 26, entropy \\ "" ) do 
  block = KV.get(hash)
  cond do
    block == nil -> DetHash.doit(entropy)
    counter < 1 -> DetHash.doit(entropy)
    true -> rng(block.data.hash, counter - 1, ran_block(block) <> entropy)
  end
	end
	def winner?(balance, total, seed, pub, j) do#each address gets 200 chances.
		max = HashMath.hex2int("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")
		b = max * Constants.signers_per_block * balance / (Constants.chances_per_address * total)
		a = HashMath.hash2int(DetHash.doit({seed, pub, j}))
		a < b and j >= 0 and j < Constants.chances_per_address and is_integer(j)
	end
	def sign_transaction(tx, txs, prev_hash) do
		#real_prev_hash = Blockchain.blockhash(Blockchain.get_block())
		acc = KV.get(tx.pub)
    tot_bonds = KV.get("tot_bonds")
    ran = rng(prev_hash)
    #prev_block = KV.get(prev_hash)
		#IO.puts("prev_hash #{inspect prev_hash}")
		prev_block = Blockchain.get_block(prev_hash)
    l = Enum.map(tx.data.winners, fn(x)->winner?(acc.bond, tot_bonds, ran, tx.pub, x) end)
    l1 = l
    l = Enum.reduce(l, true, fn(x, y) -> x and y end)
    m = length(Enum.filter(txs, fn(t) -> t.pub == tx.pub and t.data.__struct__ == :Elixir.SignTx end))
    height = KV.get("height")
    tx_prev = tx.data.prev_hash
		#IO.puts("sign tx #{inspect tx} #{inspect prev_block}")
    cond do
      acc.bond < Constants.min_bond ->
        IO.puts("not enough bond-money to validate")
        false
      not is_binary(tx.data.secret_hash) ->
        IO.put("should have been binary")
        false
      height > 1 and tx.data.height != prev_block.data.height ->
        IO.puts("bad height")
        false
      not l ->
        IO.puts("not l")
        false
      length(tx.data.winners) < 1 ->
				IO.puts("too short")
				false
      m != 0 ->
				#IO.puts("m is not 0")
				false
      not(height == 0) and tx_prev != prev_hash ->
        IO.puts("hash not match")
        false
      true -> true
    end		
	end
	def main(tx, txs, prevhash) do
		k = tx.data.__struct__
		f = case k do
      :Elixir.SignTx -> &(sign_transaction(&1, &2, prevhash))
      :Elixir.SpendTx ->                &(spend(&1, &2))
      :Elixir.Spend2WaitTx ->      &(spend2wait(&1, &2))
      :Elixir.Wait2BondTx ->        &(wait2bond(&1, &2))
      :Elixir.Bond2SpendTx ->      &(bond2spend(&1, &2))
      :Elixir.SlasherTx ->            &(slasher(&1, &2))
      :Elixir.RevealTx ->              &(reveal(&1, &2))
      :Elixir.ToChannelTx ->       &(to_channel(&1, &2))
      :Elixir.ChannelBlockTx -> &(channel_block(&1, &2))
      :Elixir.CloseChannelTx -> &(close_channel(&1, &2))
      :Elixir.OracleTx ->              &(oracle(&1, &2))
      :Elixir.JudgementTx ->        &(judgement(&1, &2))
      :Elixir.WinTx ->                    &(win(&1, &2))
			_ ->
				IO.puts("invalid tx type: #{inspect k}")
			  fn(_, _) -> false end
			end
		cond do
			not f.(tx, txs) ->
				#IO.puts("bad tx")
				false
			not Sign.verify_tx(tx) ->
				IO.puts("bad signature")
				false
			true -> true
		end
	end
		#f = [
#      {:Elixir.SignTx, &(sign_transaction(&1, &2, prev_hash))},
#      {:Elixir.SpendTx,               &(spend(&1, &2))},
#      {:Elixir.Spend2WaitTx,     &(spend2wait(&1, &2))},
#      {:Elixir.Wait2BondTx,       &(wait2bond(&1, &2))},
#      {:Elixir.Bond2SpendTx,     &(bond2spend(&1, &2))},
#      {:Elixir.SlasherTx,           &(slasher(&1, &2))},
#      {:Elixir.RevealTx,             &(reveal(&1, &2))},
#      {:Elixir.ToChannelTx,       &(to_channel(&1, &2))},
#      {:Elixir.ChannelBlockTx, &(channel_block(&1, &2))},
#      {:Elixir.CloseChannelTx, &(close_channel(&1, &2))},
#      {:Elixir.OracleTx,             &(oracle(&1, &2))},
#      {:Elixir.JudgementTx,       &(judgement(&1, &2))},
#      {:Elixir.WinTx,                   &(win(&1, &2))},
#    ]
#    default = fn(_, _) -> false end
#    cond do
#      not Dict.get(f, tx.data.__struct__, default).(tx, txs) -> false
#      not Sign.verify_tx(tx) ->
#        IO.puts("bad signature")
#        false
#      true -> true
#    end
#  end		
end
