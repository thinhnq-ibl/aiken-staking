use aiken/collection/list
use aiken/collection/pairs
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
  active_users: Pairs<VerificationKeyHash, AssetClass>,
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
  REGISTER(VerificationKeyHash, AssetClass)
  UNREGISTER(VerificationKeyHash)
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
      // Validation for Feed action when the Pool utxo is spent.
      // We check that:
      //   * the input value contains the pool utxo NFT,
      //   * the output value is equal to the input value plus the specified amount of MainTokens,
      //   * the datum doesn't change.
      // This action is used to provide reward for staker
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
      // Validation for Register action when the Pool utxo is spent.
      // We check that:
      //   * the transaction is signed by pkh,
      //   * the output pool UTxO value is equal to the input value,
      //   * the output pool UTxO datum is equal to that of the input plus the
      //       newly registered user information, which implies checking that the
      //       value of the newly created user UTxO equals the NFT created for
      //       pkh alone, and that
      //   * the datum of the user UTxO is as expected.
      REGISTER(pub_key_hash, asset_class) -> {
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
        let new_pool_datum_active_users =
          list.push(pool_datum.active_users, Pair(pub_key_hash, asset_class))
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
        new_pool_datum_active_users == new_pool_datum.active_users
      }
      // Validation for Unregister action when the User utxo is spent.
      // We must check that:
      //   * the transaction is signed by pkh,
      //   * the user UTxO cannot be found in the outputs, and that
      //   * the NFT has been burnt (TBA).
      UNREGISTER(pub_key_hash) -> {
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
        let new_pool_datum_active_users =
          pairs.delete_all(pool_datum.active_users, pub_key_hash)
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
        new_pool_datum_active_users == new_pool_datum.active_users
      }
      // Validation for Deposit action when the User utxo is spent.
      // We must check that:
      //   * the transaction is signed by the pub key specified in the user state,
      //   * the validation time range is not longer than a predefined range and
      //     the deposit time is inside it,
      //   * the deposit can be performed according to the staking business logic,
      //   * the value blocked in the utxo coincides with the expected one,
      //   * the tokens in concept of fees are distributed properly,
      //   * the output user state is the expected one.
      DEPOSIT -> todo
      // Validation for Withdraw action when the User utxo is spent.
      // We must check that:
      //   * the transaction is signed by the pub key specified in the user state,
      //   * the validation time range is not longer than a predefined range and
      //     the withdraw time is inside it,
      //   * the withdraw can be performed according to the staking business logic,
      //   * the value blocked in the utxo coincides with the expected one,
      //   * the tokens in concept of fees are distributed properly,
      //   * the output user state is the expected one.
      WITHDRAW -> todo
      // Validation for Claim action when the Pool utxo is spent.
      // We check that:
      //   * the transaction is signed by someone who is registered to the
      //       staking pool,
      //   * the validation time range is not longer than a predefined range and
      //     the claim time is inside it,
      //   * the transaction is consuming a single user UTXO (this is checked when
      //       calculating the rewards, particularly when obtaining the user input
      //       UTxO in inputUserState),
      //   * the output pool UTxO value equals that of the input minus the rewards,
      //   * the output pool UTxO datum is equal to that of the input.
      CLAIM -> todo
      // Validation for Compound action when the User utxo is spent.
      // We check that:
      //   * the pool UTxO is spent.
      //   * the public key hash in the user input UTxO datum is that of the signer
      //       of the transaction,
      //   * the output user UTxO value equals that of the input plus the rewards,
      //   * the output user UTxO datum is the expected one.
      // this action will stake curent reward to pool
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
