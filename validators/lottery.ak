use aiken/builtin
use aiken/cbor
use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash, blake2b_224}
use aiken/merkle_patricia_forestry.{MerklePatriciaForestry} as mpf
use cardano/address.{Script}
use cardano/assets.{PolicyId}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use cardano_lottery/constants.{cip67_ref_label, cip67_user_label}
use cardano_lottery/utils

pub type PubKeyHash =
  VerificationKeyHash

pub type Lottery {
  // A ticket's reference UTxO
  Ticket {
    metadata: Pairs<Data, Data>,
    version: Int,
    next_ticket: Option<ByteArray>,
    sub_ticket: Option<ByteArray>
  }
  // Head of the linked list
  Info {
    first_ticket: Option<ByteArray>,
    ticket_price: Int,
    draw_time_start: Int,
    draw_time_end: Int,
    commission_percentage_numerator: Int,
  }
  // Folding progress UTxO
  Folding {
    next_ticket: ByteArray,
    fortuna_hashes: List<ByteArray>,
    draw_time_start: Int,
    draw_time_end: Int,
    collected_tickets_so_far: MerklePatriciaForestry,
    commission_percentage_numerator: Int,
  }
  // Result of the last fold
  Reward {
    winner_tickets: List<ByteArray>,
    unburnt_tickets: MerklePatriciaForestry,
    commission: Int,
  }
  // Holding on to the list of minted NFTs so that users can burn their expired
  // tickets (reaching this point means agent's commission and all rewards are
  // paid)
  Concluded {
    unburnt_tickets: MerklePatriciaForestry
  }
}

pub type SpendAction {
  AppendTicket { own_input_index: Int }
  StartFold { lottery_info_input_index: Int, fortuna_reference_input_index: Int }
  AddFortunaHash { folding_input_index: Int, fortuna_reference_input_index: Int }
  ContinueFold { fold_progress_input_index: Int, next_ticket_input_index: Int }
  PayReward { reward_input_index: Int }
  RemoveTicket
}

pub type MintAction {
  Initiate { spent_utxo: OutputReference }
  MintTicket { covering_ticket_input_index: Int, ticket_count: Int }
  BurnTicket
}

validator lottery {
  mint(action: MintAction, own_policy: PolicyId, tx: Transaction) {
    let Transaction { extra_signatories, inputs, outputs, mint, .. } = tx

    expect mint_pairs = mint |> assets.tokens(own_policy) |> dict.to_pairs

    // expect and {
    //   // Execution of this endpoint already implies that both these policies
    //   // equal `own_policy`
    //   ref_mint_policy == user_mint_policy,
    //   // 
    //   ref_mint_qty == user_mint_qty,
    //   bytearray.take(ref_mint_name, 4) == utils.cip67_ref_label,
    //   bytearray.take(user_mint_name, 4) == utils.cip67_user_label,
    // }?

    when action is {
      Initiate { spent_utxo } -> {
        // {{{
        // To enforce uniqueness of lottery ID, specified UTxO must be spent
        utxo_is_spent(inputs, spent_utxo)

        // Exactly 2 NFTs must be minted, such that they are equal to each other
        // in compliance with CIP-67
        let
          _lottery_id,
          ref_lottery_id,
          user_lottery_id,
        <-
          ticket_id_from_out_ref(spent_utxo)

        // We don't care if other mints/burns occur in the transaction, but only
        // two NFTs of this policy must be minted
        expect [(ref_mint_name, 1), (user_mint_name, 1)] = mint_pairs

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
            reference_script: None,
          },
          Output {
            address: Address { payment_credential: VerificationKey(agent_vkh), .. },
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
          agent_value |> assets.quantity_of(own_policy, user_lottery_id)

        // The datum must contain all information of the lottery. Initiator
        // (presumably agent) is free to set them as desired. Only
        // `first_ticket` has to be set to `None`
        expect Info { first_ticket: None, .. }: Lottery = lottery_info_datum_data

        expect and {
          lottery_info_address.payment_credential == Script(own_policy),
          list.any(extra_signatories, fn(vkh) {vkh == agent_vkh}),
          info_beacon_symbol == own_policy,
          info_beacon_name == ref_lottery_id,
        }?
      }
      // }}}
      MintTicket { covering_ticket_input_index, ticket_count } -> {
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
          output_reference: spent_out_ref,
        }) = list.at(inputs, covering_ticket_input_index)

        // Covering ticket must only carry its NFT
        let (covering_ticket_symbol, covering_ticket_name, covering_ticket_qty) =
          utils.get_single_asset_from_value(covering_ticket_value)

        expect and {
          covering_ticket_symbol == own_policy,
          bytearray.take(covering_ticket_name, 4) == cip67_ref_label,
        }?

        expect covering_ticket_datum: Lottery = covering_ticket_datum_data

        expect [
          Output {
            address: cont_output_address,
            value: cont_output_value,
            datum: InlineDatum(cont_output_datum_data),
            reference_script: None,
          },
          ..remaining_outputs
        ] = outputs

        let x = {
          if ticket_count == 1 {
            // Only 2 NFTs must be minted
            expect [Pair(ref_mint_name, 1), Pair(user_mint_name, 1)] =
              mint_pairs

            // Lottery ID must be found from covering ticket's output reference
            let
              lottery_id,
              ref_lottery_id,
              user_lottery_id,
            <-
              ticket_id_from_out_ref(spent_out_ref)

            expect and {
              ref_mint_name == ref_lottery_id,
              user_mint_name == user_lottery_id,
            }?

            // We're only caring about the NFT with ref. label here, relying on
            // users' signatures for proper destination of their NFTs
            expect Output {
              address: ref_output_address,
              value: ref_output_value,
              datum: InlineDatum(ref_output_datum_data),
              reference_script: None,
            } = builtin.head_list(remaining_outputs)

            expect (ref_ticket_symbol, ref_ticket_name, 1) =
              utils.get_single_asset_from_value(ref_output_value)

            and {
              ref_ticket_symbol == own_policy,
              ref_ticket_name == ref_mint_name,
            }
          } else {
            let ref_mint_pairs = mint_pairs |> list.take(ticket_count)
            let user_mint_pairs = mint_pairs |> list.drop(ticket_count)
          }
        }
        and {
          covering_ticket_address == cont_output_address,
          covering_ticket_value == cont_output_value,
          when covering_ticket_datum is {
            Info { first_ticket, .. } -> {
              and {
                when first_ticket is {
                  Some(current_first_ticket) -> {
                  }
                  None -> {
                    True
                  }
                }
              }?
            }
            Ticket { next_ticket } -> {
              and {
                bytearray.take(covering_ticket_name, 4) == cip67_ref_label,
              }
            }
            _ -> fail @"Invalid datum for minting a new ticket"
          }
        }?
        todo
        // }}}
      }
      BurnTicket -> todo
    }
  }

  spend(
    m_lottery: Option<Lottery>,
    spend_action: Redeemer,
    own_out_ref: OutputReference,
    tx: Transaction,
  ) {
  let Transaction { inputs, mint, .. } = tx
  when spend_action is {
    AppendTicket { own_input_index } -> {
      expect Output {
        address: Address { payment_credential: Script(own_script_hash), .. },
        ..
      } = utils.get_own_input_at(inputs, own_out_ref, input_index)

      let mint_tokens = mint |> assets.tokens(own_script_hash) |> dict.to_pairs

      mint_tokens |> list.all(fn(token_pair) { token_pair.2nd == 1 })
    }
    StartFold { lottery_info_input_index, fortuna_reference_input_index } -> todo
    AddFortunaHash { folding_input_index, fortuna_reference_input_index } -> todo
    ContinueFold { fold_progress_input_index, next_ticket_input_index } -> todo
    PayReward { reward_input_index } -> todo
    RemoveTicket -> {
      expect Output {
        address: Address { payment_credential: Script(own_script_hash), .. },
        ..
      } = utils.get_own_input_at(inputs, own_out_ref, input_index)

      let mint_tokens = mint |> assets.tokens(own_script_hash) |> dict.to_pairs

      mint_tokens |> list.all(fn(token_pair) { token_pair.2nd == -1 })
    }
  }

  else(_) {
    False
  }
}
