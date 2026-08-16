---
name: contract-reader
description: Reconstructs a NEAR contract's call interface from its on-chain history — method names, argument keys, inferred types, which keys are required, and a real example payload for each method. Use when the user asks what methods a contract has, how to call one, what arguments it takes, or wants to inspect an unfamiliar NEAR contract before integrating with it.
activation:
  keywords: ["контракт", "контракта", "контракте", "методы", "метод", "аргументы", "вызов", "abi", "сигнатура", "прочитай", "contract", "method", "arguments", "call", "near", "интерфейс", "interface"]
---

# NEAR contract reader

NEAR contracts publish no ABI. To call `ft_transfer` on an unfamiliar contract you have to
know that it wants `receiver_id`, `amount` and an optional `memo` — and nothing on chain
tells you that. The only public record is what other callers already sent.

This skill reads a contract's recent transaction history from the NearBlocks API, groups the
function calls by method, and reconstructs each method's argument shape: key names, inferred
types (account ids and u128 amounts are recognised), whether a key appears in every call or
only some, and a real example payload with the transaction it came from.

## Environment rules

- The shell is **Windows cmd**, not bash. Write the path **without quotes** around it.
- `builtin__http` rejects POST — not needed here, everything is GET.

## Usage

When the user asks about a contract's methods, arguments, or how to call it, run:

```
C:\Users\user\ironclaw-ws\read-contract.bat <contract_id> [pages]
```

`pages` defaults to 2 (about 50 transactions). Raise it for quiet contracts, lower it for
busy ones. Example: `C:\Users\user\ironclaw-ws\read-contract.bat wrap.near 1`

The command takes 5–20 seconds and prints a ready report; it also saves a machine-readable
schema to `contract-<name>.json` in the same folder.

## Reporting

Show the report as-is, then help the user act on it:

- Point out which method they most likely need for their stated goal.
- Warn that `string(u128 amount)` values are in the token's smallest denomination — 24
  decimals for NEAR, 6 for USDC/USDT — so `"1000000"` is one USDC, not a million.
- A key marked `optional (2/7)` was present in only some calls; treat it as genuinely
  optional rather than guessing.
- If a method shows `arguments: none`, it is called with `{}` — say so explicitly.

Two honest limits worth stating when they matter: this reconstructs only what has actually
been called recently, so rarely-used view methods will be missing; and the types are inferred
from observed values, not from the contract source, so a field seen only as a string may
accept other shapes.

Never invent methods or arguments that were not in the output, and never report a scan you
did not run in this turn.
