use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/transaction.{OutputReference, Transaction}
 
pub type Datum {
  owner: VerificationKeyHash,
}
 
pub type Redeemer {
  msg: ByteArray,
}
 
validator staking {
  spend(
    datum: Option<Datum>,
    redeemer: Redeemer,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    expect Some(Datum { owner }) = datum
    let must_say_hello = redeemer.msg == "Hello, World!"
    let must_be_signed = list.has(self.extra_signatories, owner)
    must_say_hello && must_be_signed
  }
}

test staking_example() {
  let datum =
    Datum { owner: #"00000000000000000000000000000000000000000000000000000000" }
 
  let redeemer = Redeemer { msg: "Aiken Rocks!" }
 
  let placeholder_utxo = OutputReference { transaction_id: "", output_index: 0 }
 
  staking.spend(
    Some(datum),
    redeemer,
    placeholder_utxo,
    transaction.placeholder,
  )
}