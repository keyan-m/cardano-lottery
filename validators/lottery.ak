use aiken/cbor
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash, blake2b_224}
use cardano/address.{Script}
use cardano/assets.{PolicyId}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use cardano_lottery/utils.{MerkleRoot}

pub type PubKeyHash =
  VerificationKeyHash

pub type Lottery {
  // Head of the linked list
  Info {
    commission_percentage_numerator: Int,
    ticket_price: Int,
    draw_time_start: Int,
    draw_time_end: Int,
    first_ticket: Option<ByteArray>,
  }
  // A ticket's reference UTxO
  Ticket { next_ticket: Option<ByteArray> }
  // Folding progress UTxO
  Folding {
    commission_percentage_numerator: Int,
    fortuna_hashes: List<ByteArray>,
    draw_time_start: Int,
    draw_time_end: Int,
    collected_tickets_so_far: MerkleRoot,
    next_ticket: ByteArray,
  }
  // Result of the last fold
  Reward {
    winner_tickets: List<ByteArray>,
    unburnt_tickets: MerkleRoot,
    commission: Int,
  }
  // Holding on to the list of minted NFTs so that users can burn their expired
  // tickets (reaching this point means agent's commission and all rewards are
  // paid)
  Concluded {
    unburnt_tickets: MerkleRoot
  }
}

pub type SpendAction {
  AppendTicket
  StartFold { lottery_info_input_index: Int, fortuna_reference_input_index: Int }
  AddFortunaHash { folding_input_index: Int, fortuna_reference_input_index: Int }
  ContinueFold { fold_progress_input_index: Int, next_ticket_input_index: Int }
  PayReward { reward_input_index: Int }
  RemoveTicket
}

pub type MintAction {
  Initiate { spent_utxo: OutputReference }
  MintTicket { covering_ticket_input_index: Int, spent_utxo: OutputReference }
  BurnTicket
}

validator lottery {
  mint(action: MintAction, own_policy: PolicyId, tx: Transaction) {
    let Transaction { extra_signatories, inputs, outputs, mint, .. } = tx

    let mint_triplet = utils.get_single_asset_from_value(mint)

    expect [
      (ref_mint_policy, ref_mint_name, 1),
      (user_mint_policy, user_mint_name, 1)
    ] = mint |> assets.flatten

    // Execution of this endpoint already implies that both these policies
    // equal `own_policy`
    expect (ref_mint_policy == user_mint_policy)?

    when action is {
      Initiate { spent_utxo } -> {
        // {{{
        // To enforce uniqueness of lottery ID, specified UTxO must be spent
        utxo_is_spent(inputs, spent_utxo)

        // Exactly 2 NFTs must be minted, such that they are equal to each other
        // in compliance with CIP-67
        let Pair(ref_lottery_id, user_lottery_id) = id_from_out_ref(spent_utxo)
        expect and {
          ref_mint_name == ref_lottery_id,
          user_mint_name == user_lottery_id,
        }?

        // First produced UTxO must be at the script address, containing the
        // minted NFT, second UTxO must be outside this contract, containing the
        // `222` NFT for agent (used for verification in folding and commission
        // collection)
        expect [
          Output {
            address: lottery_info_address,
            value: lottery_info_value,
            datum: InlineDatum(lottery_info_datum_data),
            ..
          },
          Output {
            address: Address { payment_credential: agent_payment_credential, .. },
            value: agent_value,
            ..
          },
          ..
        ] = outputs

        // List head (i.e. lottery info) UTxO must contain only one NFT apart
        // from Lovelaces
        expect (info_beacon_symbol, info_beacon_name, 1) =
          utils.get_single_asset_from_value_apart_from_ada(lottery_info_value)
        // Agent's UTxO must contain corresponding `222` NFT
        expect 1 =
          assets.quantity_of(agent_value, own_policy, user_lottery_id)

        // The datum must contain all information of the lottery. Initiator
        // (presumably agent) is free to set them as desired. Only
        // `first_ticket` has to be set to `None`
        expect Info { first_ticket: None, .. }: Lottery = lottery_info_datum_data

        let own_script = Script(own_policy)
        expect and {
          lottery_info_address.payment_credential == own_script,
          !(agent_address.payment_credential == own_script),
          info_beacon_symbol == own_policy,
          info_beacon_name == ref_lottery_id,
        }?
      }
      // }}}
      MintTicket { covering_ticket_input_index } -> {
        // {{{
        // Farther down we expect this UTxO to be reproduced at index 0,
        // consequently enforcing a single UTxO getting spent.
        expect Some(Input {
          output: Output {
            address: covering_ticket_address,
            value: covering_ticket_value,
            datum: InlineDatum(covering_ticket_datum_data),
            ..
          },
          ..
        }) = list.at(inputs, covering_ticket_input_index)
        let (covering_ticket_symbol, covering_ticket_name, covering_ticket_qty) =
          utils.get_single_asset_from_value(covering_ticket_value)
        expect (covering_ticket_symbol == own_policy)?
        expect covering_ticket_datum: Lottery = covering_ticket_datum_data
        expect [
          Output {
            address: cont_output_address,
            value: cont_output_value,
            datum: InlineDatum(cont_output_datum_data),
            reference_script: None,
          },
          Output {
            address: new_ticket_ref_address,
            value: new_ticket_ref_value,
            datum: InlineDatum(new_ticket_ref_datum_data),
            reference_script: None,
          },
          Output {
            address: new_ticket_address,
            value: new_ticket_value,
            datum: InlineDatum(new_ticket_datum_data),
            reference_script: None,
          },
          ..
        ] = outputs
        when covering_ticket_datum is {
          Info { first_ticket } -> {
            and {
              when first_ticket is {
                Some(current_first_ticket) -> {
                }
                None -> {
                }
              }
            }?
          }
          Ticket { next_ticket } -> {
            and {
              bytearray.take(covering_ticket_name, 4) == utils.cip67_ref_label,
            }
          }
          _ -> fail @"Invalid datum for minting a new ticket"
        }
        todo
        // }}}
      }
    }
  }

  else(_) {
    False
  }
}

fn utxo_is_spent(inputs: List<Input>, utxo_out_ref: OutputReference) {
  expect list.any(inputs, fn(input) { input.output_reference == spent_utxo })?
}

fn id_from_out_ref(out_ref: OutputReference) -> Pair<ByteArray, ByteArray> {
  let common = out_ref |> cbor.serialise |> blake2b_224
  // Note that both names end up 32 bytes long (max allowed for token names).
  Pair(
    common |> bytearray.push(utils.cip67_ref_label),
    common |> bytearray.push(utils.cip67_user_label)
  )
}
