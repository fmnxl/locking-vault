LockingVault.sol
================

An modification to [Solmate's](https://github.com/transmissions11/solmate/blob/main/src/mixins/ERC4626.sol)
[ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) implementation in which withdrawals do not directly transfer the underlying asset to the receiver.


### Design

- Instead of extending ERC-20, this contract uses [ERC-1155 standard Multi-Token Standard](https://eips.ethereum.org/EIPS/eip-1155) to represents multiple tokens:
	- `id=0` represents shares, equivalent to ERC-4626's ERC-20 share tokens,
	- `id>0` represent "receipts", which are exchangable 1-to-1 to the underlying asset. Each withdrawal creates a new token `id`.
- This contract relies on Solmate's solid share accounting logic for asset token <=> shares conversion.
- After withdrawal, the user would stop receiving yield from the withdrawn shares, if any.
- Redemptions are designed to return the max allowable amount of assets instead of a user-provided value, as it is most probably the user's intention.

### Implementation

#### `afterMintReceipt(uint256 id, uint256 assets)` 
- Record total unlocking assets on every withdrawal in a storage variable.
 
#### `totalAssets()`
- Should not include unlocking assets, which are reserved for receipts redemptions

#### `unlockableAssets(uint256 id)`
- Should return the current amount of assets that can be redeemed for the given receipt.
- You may implement different conditions for the redemption, such as after a set period of time after the withdrawal, or vesting the amount redeemable.


### TODO

- [x] Implement initial contract
- [ ] Implement tests
- [ ] Add example vault implementations
  - [ ] Unlocks all token at once 
  - [ ] Vest withdrawn token over time
  - [ ] Restaking unlocked assets
