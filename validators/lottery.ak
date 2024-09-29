use aiken/cbor
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash, sha2_256}
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
    // MPF root
    collected_tickets_so_far: ByteArray,
    next_ticket: ByteArray,
  }
  Reward { winner_ticket: ByteArray }
}

pub type SpendAction {
  AppendTicket
  StartFold { lottery_info_input_index: Int }
  ContinueFold { fold_progress_input_index: Int, next_ticket_input_index: Int }
  CollectPrize
}

pub type MintAction {
  Initiate { spent_utxo: OutputReference }
  MintTicket { covering_ticket_input_index: Int }
}

validator lottery {
  mint(action: MintAction, own_policy: PolicyId, tx: Transaction) {
    let Transaction { extra_signatories, inputs, outputs, mint, .. } = tx

    let mint_triplet = utils.get_single_asset_from_value(mint)

    let (_, mint_name, mint_quantity) = mint_triplet

    when action is {
      Initiate { spent_utxo } -> {
        // {{{
        // To enforce uniqueness of lottery ID, specified UTxO must be spent.
        expect
          list.any(inputs, fn(input) { input.output_reference == spent_utxo })?

        // Only a single NFT must be minted, such that its name equals hash of
        // the spent UTxO's output reference.
        let lottery_id = spent_utxo |> cbor.serialise |> sha2_256
        expect (mint_name == lottery_id)?
        expect (mint_quantity == 1)?

        // First produced UTxO must be at the script address, containing the
        // minted NFT.
        expect [
          Output {
            address: lottery_info_address,
            value: lottery_info_value,
            datum: InlineDatum(lottery_info_datum_data),
            ..
          },
          ..
        ] = outputs
        expect (lottery_info_address.payment_credential == Script(own_policy))?

        // The datum must contain all information of the lottery. `agent` is
        // free to set them as desired.
        expect Info { agent, .. }: Lottery = lottery_info_datum_data

        // List head (i.e. lottery info) UTxO must contain only one other asset
        // apart from Lovelaces.
        let lottery_info_beacon =
          utils.get_single_asset_from_value(lottery_info_value)

        and {
          // List head's asset must match the minted asset.
          lottery_info_beacon == mint_triplet,
          // Initiation must be signed by the lottery agent.
          list.any(extra_signatories, fn(vkh) { vkh == agent }),
        }?
      }
      // }}}
      MintTicket { covering_ticket_input_index } -> {
        expect Some(Input {
          output: Output {
            address: covering_ticket_address,
            value: covering_ticket_value,
            datum: InlineDatum(covering_ticket_datum_data),
            ..
          },
          ..
        }) = list.at(inputs, covering_ticket_input_index)
        todo
      }
    }
  }

  else(_) {
    False
  }
}
