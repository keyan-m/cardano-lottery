use aiken/builtin
use aiken/primitive/bytearray
use cardano/assets.{AssetName, PolicyId, Value}
use cardano/transaction.{Input, Output, OutputReference}
use cardano_lottery/constants.{cip67_ref_label, cip67_user_label, cip68_version}

// Credit for these fold functions goes to KtorZ
// {{{
type Scott2<a, b, result> =
  fn(a, b) -> result

type Scott3<a, b, c, result> =
  fn(a, b, c) -> result

type Scott4<a, b, c, d, result> =
  fn(a, b, c, d) -> result

type Scott5<a, b, c, d, e, result> =
  fn(a, b, c, d, e) -> result

type Scott6<a, b, c, d, e, f, result> =
  fn(a, b, c, d, e, f) -> result

fn do_foldr2(
  self: List<x>,
  with: fn(x, a, b, Scott2<a, b, result>) -> result,
  return: Scott2<a, b, result>,
) -> Scott2<a, b, result> {
  when self is {
    [] -> return
    [x, ..xs] -> do_foldr2(xs, with, fn(a, b) { with(x, a, b, return) })
  }
}

fn do_foldr3(
  self: List<x>,
  with: fn(x, a, b, c, Scott3<a, b, c, result>) -> result,
  return: Scott3<a, b, c, result>,
) -> Scott3<a, b, c, result> {
  when self is {
    [] -> return
    [x, ..xs] -> do_foldr3(xs, with, fn(a, b, c) { with(x, a, b, c, return) })
  }
}

fn do_foldr4(
  self: List<x>,
  with: fn(x, a, b, c, d, Scott4<a, b, c, d, result>) -> result,
  return: Scott4<a, b, c, d, result>,
) -> Scott4<a, b, c, d, result> {
  when self is {
    [] -> return
    [x, ..xs] ->
      do_foldr4(xs, with, fn(a, b, c, d) { with(x, a, b, c, d, return) })
  }
}

fn do_foldr5(
  self: List<x>,
  with: fn(x, a, b, c, d, e, Scott5<a, b, c, d, e, result>) -> result,
  return: Scott5<a, b, c, d, e, result>,
) -> Scott5<a, b, c, d, e, result> {
  when self is {
    [] -> return
    [x, ..xs] ->
      do_foldr5(xs, with, fn(a, b, c, d, e) { with(x, a, b, c, d, e, return) })
  }
}

fn do_foldr6(
  self: List<x>,
  with: fn(x, a, b, c, d, e, f, Scott6<a, b, c, d, e, f, result>) -> result,
  return: Scott6<a, b, c, d, e, f, result>,
) -> Scott6<a, b, c, d, e, f, result> {
  when self is {
    [] -> return
    [x, ..xs] ->
      do_foldr6(
        xs,
        with,
        fn(a, b, c, d, e, f) { with(x, a, b, c, d, e, f, return) },
      )
  }
}

pub fn foldl2(
  self: List<x>,
  zero_a: a,
  zero_b: b,
  with: fn(x, a, b, Scott2<a, b, result>) -> result,
  return: Scott2<a, b, result>,
) -> result {
  when self is {
    [] -> return(zero_a, zero_b)
    [x, ..xs] -> {
      let acc_a, acc_b <- with(x, zero_a, zero_b)
      foldl2(xs, acc_a, acc_b, with, return)
    }
  }
}

pub fn foldr2(
  self: List<x>,
  zero_a: a,
  zero_b: b,
  with: fn(x, a, b, Scott2<a, b, result>) -> result,
  return: Scott2<a, b, result>,
) -> result {
  do_foldr2(self, with, return)(zero_a, zero_b)
}

pub fn foldl3(
  self: List<x>,
  zero_a: a,
  zero_b: b,
  zero_c: c,
  with: fn(x, a, b, c, Scott3<a, b, c, result>) -> result,
  return: Scott3<a, b, c, result>,
) -> result {
  when self is {
    [] -> return(zero_a, zero_b, zero_c)
    [x, ..xs] -> {
      let acc_a, acc_b, acc_c <- with(x, zero_a, zero_b, zero_c)
      foldl3(xs, acc_a, acc_b, acc_c, with, return)
    }
  }
}

pub fn foldr3(
  self: List<x>,
  zero_a: a,
  zero_b: b,
  zero_c: c,
  with: fn(x, a, b, c, Scott3<a, b, c, result>) -> result,
  return: Scott3<a, b, c, result>,
) -> result {
  do_foldr3(self, with, return)(zero_a, zero_b, zero_c)
}

pub fn foldl4(
  self: List<x>,
  zero_a: a,
  zero_b: b,
  zero_c: c,
  zero_d: d,
  with: fn(x, a, b, c, d, Scott4<a, b, c, d, result>) -> result,
  return: Scott4<a, b, c, d, result>,
) -> result {
  when self is {
    [] -> return(zero_a, zero_b, zero_c, zero_d)
    [x, ..xs] -> {
      let acc_a, acc_b, acc_c, acc_d <- with(x, zero_a, zero_b, zero_c, zero_d)
      foldl4(xs, acc_a, acc_b, acc_c, acc_d, with, return)
    }
  }
}

pub fn foldr4(
  self: List<x>,
  zero_a: a,
  zero_b: b,
  zero_c: c,
  zero_d: d,
  with: fn(x, a, b, c, d, Scott4<a, b, c, d, result>) -> result,
  return: Scott4<a, b, c, d, result>,
) -> result {
  do_foldr4(self, with, return)(zero_a, zero_b, zero_c, zero_d)
}

pub fn foldl5(
  self: List<x>,
  zero_a: a,
  zero_b: b,
  zero_c: c,
  zero_d: d,
  zero_e: e,
  with: fn(x, a, b, c, d, e, Scott5<a, b, c, d, e, result>) -> result,
  return: Scott5<a, b, c, d, e, result>,
) -> result {
  when self is {
    [] -> return(zero_a, zero_b, zero_c, zero_d, zero_e)
    [x, ..xs] -> {
      let
        acc_a,
        acc_b,
        acc_c,
        acc_d,
        acc_e,
      <- with(x, zero_a, zero_b, zero_c, zero_d, zero_e)
      foldl5(xs, acc_a, acc_b, acc_c, acc_d, acc_e, with, return)
    }
  }
}

pub fn foldr5(
  self: List<x>,
  zero_a: a,
  zero_b: b,
  zero_c: c,
  zero_d: d,
  zero_e: e,
  with: fn(x, a, b, c, d, e, Scott5<a, b, c, d, e, result>) -> result,
  return: Scott5<a, b, c, d, e, result>,
) -> result {
  do_foldr5(self, with, return)(zero_a, zero_b, zero_c, zero_d, zero_e)
}

pub fn foldl6(
  self: List<x>,
  zero_a: a,
  zero_b: b,
  zero_c: c,
  zero_d: d,
  zero_e: e,
  zero_f: f,
  with: fn(x, a, b, c, d, e, f, Scott6<a, b, c, d, e, f, result>) -> result,
  return: Scott6<a, b, c, d, e, f, result>,
) -> result {
  when self is {
    [] -> return(zero_a, zero_b, zero_c, zero_d, zero_e, zero_f)
    [x, ..xs] -> {
      let
        acc_a,
        acc_b,
        acc_c,
        acc_d,
        acc_e,
        acc_f,
      <- with(x, zero_a, zero_b, zero_c, zero_d, zero_e, zero_f)
      foldl6(xs, acc_a, acc_b, acc_c, acc_d, acc_e, acc_f, with, return)
    }
  }
}

pub fn foldr6(
  self: List<x>,
  zero_a: a,
  zero_b: b,
  zero_c: c,
  zero_d: d,
  zero_e: e,
  zero_f: f,
  with: fn(x, a, b, c, d, e, f, Scott6<a, b, c, d, e, f, result>) -> result,
  return: Scott6<a, b, c, d, e, f, result>,
) -> result {
  do_foldr6(self, with, return)(zero_a, zero_b, zero_c, zero_d, zero_e, zero_f)
}

// }}}

pub fn get_single_asset_from_value(v: Value) -> (PolicyId, AssetName, Int) {
  // A single asset was expected.
  expect [triplet] =
    v
      |> assets.flatten
  triplet
}

// This functions assumes the "first" asset is ADA.
pub fn get_single_asset_from_value_apart_from_ada(
  v: Value,
) -> (PolicyId, AssetName, Int) {
  // Exactly two assets are expected.
  expect [_, triplet] = v |> assets.flatten
  triplet
}

pub fn validate_mint_labels(
  triplet0: (PolicyId, AssetName, Int),
  triplet1: (PolicyId, AssetName, Int),
) -> ((PolicyId, AssetName, Int), (PolicyId, AssetName, Int)) {
  let (_, t0, _) = triplet0
  let (_, t1, _) = triplet1
  let l0IsCip67 = bytearray.take(t0, 4) == cip67_ref_label
  let l1IsCip67 = bytearray.take(t1, 4) == cip67_ref_label
  if l0IsCip67 && !l1IsCip67 {
    (triplet0, triplet1)
  } else if !l0IsCip67 && l1IsCip67 {
    (triplet1, triplet0)
  } else {
    fail @"Exactly one of the two mints must be prefixed with CIP-67 `100`"
  }
}

// Copied over from the Fortuna repo:
// https://github.com/cardano-miners/fortuna/blob/32a5edf5b56c8d8a97c45eae254a70d1c66bd972/lib/fortuna/utils.ak#L6-L17
pub fn resolve_output_reference(
  inputs: List<Input>,
  output_ref: OutputReference,
) -> Output {
  expect [input, ..] = inputs
  if input.output_reference == output_ref {
    input.output
  } else {
    resolve_output_reference(builtin.tail_list(inputs), output_ref)
  }
}

pub fn utxo_is_spent(inputs: List<Input>, utxo_out_ref: OutputReference) {
  expect list.any(inputs, fn(input) { input.output_reference == spent_utxo })?
}

pub fn ticket_id_from_out_ref(integer_prefix: Int, out_ref: OutputReference, return: Scott3<ByteArray, ByteArray, ByteArray, result>) -> result {
  // First two bytes should be from the `integer_prefix`, which is there to
  // allow multiple tickets to be minted.
  let header = bytearray.from_int_big_endian(integer_prefix, 2)

  let common =
    header
      |> bytearray.concat(out_ref |> cbor.serialise)
      |> blake2b_224

  // Note that both names end up 32 bytes long (max allowed for token names).
  return(
    common,
    common |> bytearray.push(utils.cip67_ref_label),
    common |> bytearray.push(utils.cip67_user_label),
  )
}

pub fn get_own_input_at(
  inputs: List<Input>,
  own_out_ref: OutputReference,
  input_index: Int,
) -> Output {
  expect Some(Input { output: own_utxo, output_reference: spent_own_out_ref }) =
    list.at(inputs, input_index)
  expect (own_out_ref == spent_own_out_ref)?
  own_utxo
}

pub fn make_ticket_metadata(token_name: ByteArray) -> Pairs<Data, Data> {
  [Pair(@"name", token_name), Pair(@"image", @"TODO")]
}

pub fn validate_multiple_mints(
  own_policy: PolicyId,
  spent_out_ref: OutputReference,
  total_count: Int,
  mint_pairs: Pairs<ByteArray, Int>,
  outputs: List<Output>,
) -> Bool {
  let ref_mint_pairs = mint_pairs |> list.take(ticket_count)
  let user_mint_pairs = mint_pairs |> list.drop(ticket_count)
  let _, _ <- foldl2(
    ref_mint_pairs,
    user_mint_pairs,
    outputs,
    fn(ref_mint_pair, remaining_user_mint_pairs, remaining_outputs, return) {
      expect Pair(user_mint_name) = 
    },
  )
}

pub fn validate_ticket_mint_one_of_many(
  own_policy: PolicyId,
  spent_out_ref: OutputReference,
  index: Int,
  ref_mint_pair: Pair<ByteArray, Int>,
  user_mint_pair: Pair<ByteArray, Int>,
  corresponding_output: Output,
) -> Bool {
  expect Pair(ref_mint_name, 1) = ref_mint_pair
  expect Pair(user_mint_name, 1) = user_mint_pair

  // We're only caring about the NFT with ref. label here, relying on users'
  // signatures for proper destination of their NFTs
  expect Output {
    address: ref_output_address,
    value: ref_output_value,
    datum: InlineDatum(ref_output_datum_data),
    reference_script: None,
  } = corresponding_output

  expect (ref_ticket_symbol, ref_ticket_name, 1) =
    get_single_asset_from_value(ref_output_value)

  // Lottery ID must be found from covering ticket's output reference
  let
    lottery_id,
    ref_lottery_id,
    user_lottery_id,
  <-
    ticket_id_from_out_ref(index, spent_out_ref)

  let expected_datum = Ticket {
    metadata: make_ticket_metadata(lottery_id),
    version: cip68_version,
  }
  expect Ticket {metadata, version,} = ref_output_datum_data

  expect and {
    ref_ticket_symbol == own_policy,
    ref_ticket_name == ref_mint_name,
    ref_mint_name == ref_lottery_id,
    user_mint_name == user_lottery_id,
  }?
}
