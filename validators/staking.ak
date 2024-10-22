use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{AssetName, PolicyId}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}

pub type AssetClass =
  (PolicyId, AssetName)

type POSIXTime =
  Int

pub type PoolDatumType {
  activeUsers: List<Pair<VerificationKeyHash, AssetClass>>,
}

pub type UserDatumType {
  user: VerificationKeyHash,
  deposits: List<(Int, POSIXTime)>,
  lastClaim: Option<POSIXTime>,
}

pub type Datum {
  PoolDatum(PoolDatumType)
  UserDatum(UserDatumType)
}

pub type Redeemer {
  FEED
  DEPOSIT
  WITHDRAW
  REGISTER
  UNREGISTER
  CLAIM
  COMPOUND
}

pub type Redeemer1 {
  msg: ByteArray,
}

pub fn get_payment_cred(address: Address) -> ByteArray {
  when address.payment_credential is {
    Script(script) -> script
    VerificationKey(vkey) -> vkey
  }
}

validator staking(pool_policy_id: PolicyId, pool_asset_name: AssetName) {
  spend(
    datum: Option<Datum>,
    redeemer: Redeemer,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    let Transaction { inputs, withdrawals, extra_signatories, outputs, .. } =
      self

    when redeemer is {
      FEED -> {
        let main_input =
          list.find(
            inputs,
            fn(
              Input { output: Output { address: pool_addr, value: v, .. }, .. },
            ) {
              assets.quantity_of(v, pool_policy_id, pool_asset_name) == 1
            },
          )
        expect Some(input) = main_input
        let own_script_addr = input.output.address
        expect Some(PoolDatum(pool_datum)) = datum
        let main_output =
          list.find(
            outputs,
            fn(Output { address: addr, value: v, .. }) {
              // check NFT and output addr
              assets.quantity_of(v, pool_policy_id, pool_asset_name) == 1 && addr == own_script_addr
            },
          )
        expect Some(output) = main_output
        expect InlineDatum(new_datum) = output.datum
        expect Some(PoolDatum(new_pool_datum)) = new_datum
        // pool datum is not changed
        pool_datum == new_pool_datum
      }
      DEPOSIT -> todo
      WITHDRAW -> todo
      REGISTER -> todo
      UNREGISTER -> todo
      CLAIM -> todo
      COMPOUND -> todo
    }
    // let must_say_hello = redeemer.msg == "Hello, World!"
    // let must_be_signed = list.has(self.extra_signatories, owner)
    // must_say_hello && must_be_signed
  }

  else(_) {
    fail
  }
}
// test staking_example() {
//   todo
//   // let datum =
//   //   Datum { owner: #"00000000000000000000000000000000000000000000000000000000" }
//   // let redeemer = Redeemer1 { msg: "Aiken Rocks!" }
//   // let placeholder_utxo = OutputReference { transaction_id: "", output_index: 0 }
//   // staking.spend(
//   //   Some(datum),
//   //   redeemer,
//   //   placeholder_utxo,
//   //   transaction.placeholder,
//   // )
// }
