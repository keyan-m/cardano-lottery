# Cardano Lottery

A decentralized and trust-less lottery contract on Cardano, leveraging the
randomness of the proof-of-work token, [Fortuna](https://minefortuna.com/).

## How does it work?

1. An "agent" starts a lottery, specifying a few values:
   - A time range for capturing Fortuna block hashes
   - A commission percentage (of the total pool) to cover the transaction costs
     (this'll be on top of all the ADA)
   - Ticket price in $TUNA

   This'll produce a linked list head, and also sends an authentication NFT to
   the agent

2. Participants buy tickets, having them recorded in the linked list, and
   getting a corresponding NFT themselves (CIP-68 for now), where token names
   are derived from a specified spent UTxO (CIP-67 labels plus Blake2b-224
   digest of the serialized output reference)

3. During the specified time window, anyone can update the list head to capture
   a Fortuna block hash

4. Additionally, if the time range has not passed yet and new Fortuna blocks are
   mined, anyone can add extra hashes

5. After the time window, anyone will be able to fold the linked list,
   accumulating all the funds, and also all ticket IDs in
   a [Merkle Patricia Forestry](https://github.com/aiken-lang/merkle-patricia-forestry) (incentivized
   entities are the agent and winner(s), as they are known at this point)

6. The final fold must have all the winners specified (this'll be done by
   modding captured Fortuna hashes by the total number of participants in order
   to find winners' indices)

7. After all winners are paid, the agent gets to collect his/her commission

8. Merkle root of remaining unburnt tickets is preserved so that participants
   can burn their tickets if they wanted to

While an agent may not be required, it is implemented here so that all the
Fortuna contributors (from original authors to miner developers) can be rewarded
for their works.
