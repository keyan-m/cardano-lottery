use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/address.{Script}
use cardano/assets.{PolicyId}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use cardano_lottery/utils

pub type PubKeyHash =
  VerificationKeyHash

pub type Lottery {
  Info {
    agent: PubKeyHash,
    commission: Int,
    draw_time_start: Int,
    draw_time_end: Int,
    first_ticket: Option<ByteArray>,
  }
  Ticket { pubkey: PubKeyHash, next_ticket: Option<ByteArray> }
  Folding {
    agent: PubKeyHash,
    commission: Int,
    fortuna_hash: ByteArray,
    collected_tickets_so_far: ByteArray,
    // MPF root
    next_ticket: ByteArray,
  }
  Reward { winner_ticket: ByteArray }
}

pub type SpendAction {
  AppendTicket
  StartFold { lottery_info_input_index: Int }
  ContinueFold { fold_progress_input_index: Int, next_ticket_input_index: Int}
  CollectPrize
}

pub type MintAction {
  Initiate
  MintTicket
}

validator lottery(ref_utxo: OutputReference) {
  mint(action: MintAction, own_policy: PolicyId, tx: Transaction) {
    let Transaction { extra_signatories, inputs, outputs, mint, .. } = tx

    let mint_triplet = utils.get_single_asset_from_value(mint)

    let (_, mint_name, mint_quantity) = mint_triplet

    when action is {
      Initiate -> {
        // To enforce a single initiation, the specified UTxO must be spent.
        expect
          list.any(inputs, fn(input) { input.output_reference == ref_utxo })?

        // Only a single, nameless token must be minted.
        expect (mint_name == #"")?
        expect (mint_quantity == 1)?

        // Only one UTxO must be produced at the script address.
        let own_script = Script(own_policy)
        expect [
          Output {
            datum: InlineDatum(lottery_info_datum_data),
            value: lottery_info_value,
            ..
          },
        ] =
          list.filter(
            outputs,
            fn(output) { output.address.payment_credential == own_script },
          )

        // Linked list must be empty at initiation.
        expect Info { agent, .. }: Lottery = lottery_info_datum_data

        // List head UTxO must contain only one other asset apart from Lovelaces.
        let lottery_info_beacon =
          utils.get_single_asset_from_value(lottery_info_value)

        and {
          // List head's asset must match the minted asset.
          lottery_info_beacon == mint_triplet,
          // Initiation must be signed by the lottery agent.
          list.any(extra_signatories, fn(vkh) { vkh == agent }),
        }?
      }
      MintTicket -> False
    }
  }

  else(_) {
    False
  }
}
