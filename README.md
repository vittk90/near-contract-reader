# near-contract-reader

An [IronClaw](https://github.com/nearai/ironclaw) skill that reconstructs a NEAR contract's
call interface from its on-chain history.

## The problem

NEAR contracts publish no ABI. To call `ft_transfer` on an unfamiliar contract you need to
know it expects `receiver_id`, `amount` and an optional `memo` — and nothing on chain tells
you that. You end up reading Rust source, if it is even published, or guessing and burning
gas on failed calls.

The one public record of a contract's real interface is what other callers have already
sent. This skill reads that.

## What it does

Given a contract account, it pulls recent transactions from the NearBlocks API, keeps the
`FUNCTION_CALL` actions, groups them by method and reconstructs each method's argument shape:

- argument keys, with types inferred from observed values — account ids and u128 amounts are
  recognised rather than lumped in as plain strings
- whether a key appeared in every call or only some, so optional arguments are visible — a
  method seen only once is labelled `seen once` rather than pretending its keys are mandatory
- a real example payload, and the transaction hash it came from

Output goes to the console as a report, and to `contract-<name>.json` as a machine-readable
schema.

## Example

```
> read-contract.bat wrap.near 1

NEAR CONTRACT READER - wrap.near
scanned 18 function calls from the last 1 page(s) of history
======================================================================

method: ft_transfer   [5 calls]
  arguments:
    amount                 string(u128 amount)      always present
    memo                   string | null            always present
    receiver_id            string(account_id)       always present
  example: {"memo": "Ref Buy via 1Click", "amount": "4036311017624097897727462", "receiver_id": "ffe434aa2196..."}
  seen in: B5Gv4nEbvBMVXJgmzy5PTWzkwYLpubrxQkWV9WAWbkGp

method: storage_deposit   [3 calls]
  arguments:
    account_id             string(account_id)       always present
    registration_only      bool                     always present
  example: {"account_id": "ffe434aa2196...", "registration_only": true}
```

## Install

Copy `skill/SKILL.md` into your IronClaw skills directory as
`<skills>/near-contract-reader/SKILL.md`, put the two scripts somewhere stable, and adjust
the path inside the skill if you did not use `C:\Users\user\ironclaw-ws`. Restart
`ironclaw serve` — skills are read at startup.

Then just ask:

> what methods does intents.near have and how are they called?

## Usage without an agent

```
read-contract.bat <contract_id> [pages]
powershell -File near-contract-reader.ps1 -Contract intents.near -Pages 3 -Method ft_transfer
```

`pages` defaults to 2, roughly 50 transactions. Raise it for quiet contracts.

## Limits, stated honestly

- It sees only what has been called recently. Rarely-used and view methods will be missing.
- Types are inferred from observed values, not from contract source. A field only ever seen
  as a string may well accept other shapes.
- It depends on the public NearBlocks API and its rate limits; the script sleeps between
  pages to stay polite.

## Licence

MIT.
