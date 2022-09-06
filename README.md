# helo welcome to Wheyfus anonymous :3

Shared sudoswap LPing, bonding, staking and call option farming.

<img src="./assets/wheyfu2.gif" alt="wheyfu2" width="100%"/>

Ok pls allow me to take u through a tour of the contracts.

```
forge install
forge test
```

Here's how it works:

* Step 1: You mint some wheyfu's
* Step 2: Take equal parts wheyfus and eth and LP them into a shared sudoswap pool.
* Step 3: Receive some LP tokens representing your share in the pool.
---
* Step 4a: Take those LP tokens and bond them for a fixed term in option bonds.
* Step 5a: At bond maturity, claim back your LP tokens + call option tokens for *MOARRR* wheyfus.
* Step 6a: Convert those call option tokens into actual call options via putty.
* Step 7a: Exercise the call options.
* Step 8a: With your new wheyfus you can then go back to step 2.
---
* Step 4b: Take those LP tokens and bond them for a fixed term in xyk pool fee bonds.
* Step 5b: At bond maturity, claim back your LP tokens + fees generated from the shared xyk sudo pool.
* Step 6b: With ur new eth go back to step 2.

\*blows kiss\* <sup>*teehee*</sup>

NB:
* The longer you bond, the higher your relative yield boost.
* Each option expires in 5 years and has a strike of N wheyfus * 0.1 ether.
* 18000 wheyfus in the form of option contracts are distributed over 900 days.

<img src="./assets/wheyfu3.gif" alt="wheyfu3" width="100%"/>

Distribution: ^_^
* 9000 is reserved for a free mint
* 18000 is reserved for yield farming
* 3000 is reserved for the team

---

## More technical overview

The contracts are split into 3 parts: `Wheyfu.sol`, `OptionBonding.sol`, `FeeBonding.sol`.

## `Wheyfu.sol`

This contract is the entrypoint.

It contains 3 key functions that are related to the logic:

**mint(uint256 amount)**

Allows any whitelisted party to mint an NFT and then returns the new total supply.
The whitelist is controlled by the owner and can be modified while closedWhitelist is equal to false.


**addLiquidity(uint256[] calldata tokenIds, uint256 minPrice, uint256 maxPrice)**

Adds liquidity into a shared sudoswap pool that uses the xyk curve. Then mints ERC20 LP tokens to the
depositer representing their share of liquidity in the pool. The depositor must send equal parts ETH and 
Wheyfus to deposit into the pool. The deposit logic is very similar to UNI-v2. The xyk curve can be found
here: https://github.com/sudoswap/lssvm/blob/main/src/bonding-curves/XykCurve.sol.


**removeLiquidity(uint256[] calldata tokenIds, uint256 minPrice, uint256 maxPrice)**

Removes liquidity from the shared sudoswap pool. The user specifies which Wheyfus they want to withdraw
from the pool. From this, we can also calculate how much ETH to withdraw from the pool. The wheyfus and
ETH withdrawn are sent to the user. Then a proportional amount of ERC20 LP tokens are burnt from the
user's wallet. Again, this is very similar to the UNI-v2 logic.

There is also another function:

**onExercise(PuttyV2.Order memory order, address exerciser, uint256[] memory)**

This is called by putty when the call option for the wheyfus are being exercised. When this happens,
we mint N amount of wheyfus to the exerciser's wallet. The amount of wheyfus to mint is determined by
the tokenId of the first asset in ERC721Assets. The amount to mint is type(uint256).max - tokenId.

Related to this is the overriden function safeTransferFrom. In this function we make 2 modifications.
The first modification is to skip transferring if mintingOption is set to 2. When minting an option
putty will try to transfer wheyfus from the Wheyfu.sol contract into putty. We skip this transfer to 
save gas. Instead we do a mint to the exerciser's wallet at the point of exercise via the onExercise 
method.

The second modification is to skip transferring if the tokenId is greater than the MAX_SUPPLY, from == putty
and msg.sender == putty. This because on exercise putty will try to transfer the very large tokenId to the
exerciser. Of course, this token doesn't actually exist. So we skip transferring it (N amount of wheyfus) will
be minted via onExercise instead.

These modifications are a bit strange, but they save quite a lot of gas. Instead of the regular flow of
```
mint(N) -> fillOrder -> transferIn(N) -> exercise -> transferOut(N)
```
with the modifications, it is now:
```
fillOrder -> exercise -> mint(N)
```

## `OptionBonding.sol`

This contract contains all of the logic for the option bonds.
It is based on the staking rewards contract here: https://solidity-by-example.org/defi/staking-rewards/.
Call option ERC20 tokens are distrbuted linearly over time to stakers.

There are 3 main functions:

**optionStake(uint128 amount, uint256 termIndex)**

This function takes in an LP token amount and a termIndex. The termIndex indexes into an array of bond term options.
The term options are as follows: `[0, 7 days, 30 days, 90 days, 180 days, 365 days]`. This represents how long the bond
will last until the user can withdraw. When a user stakes, an NFT representing their bond is minted to them. We also update
all of the yield rewards and transfer the LP tokens from the user's wallet into the contract.

**optionUnstake(uint256 tokenId)**

This unstakes a bond with a particular tokenId. It checks that the user owns the bond NFT they are trying to unstake and also
that the bond has matured/expired. Then we update all of the yield rewards and burn the bond NFT from the user's wallet. The LP
tokens are transferred back to the user along with the new call option tokens that they earned in yield.

**convertToOption(uint256 numAssets, uint256 nonce)**

This converts call option ERC20 tokens into actual putty call option contracts. The ERC20 tokens are converted 1:1 for option 
contracts. It burns the ERC20 call option tokens from the user's wallet and then mints a call option contract on putty and
sends it to the user.

## `FeeBonding.sol`

This contract contains all of the logic for the LP fee bonds.
It is loosely based on the staking rewards contract here: https://solidity-by-example.org/defi/staking-rewards/.
Fees are distributed every time somebody stakes, unstakes or the skim() method is called.

There are 3 main functions:

**feeStake(uint128 amount, uint256 termIndex)**

This function takes in an LP token amount and a termIndex. The termIndex indexes into an array of bond term options.
The term options are as follows: `[0, 7 days, 30 days, 90 days, 180 days, 365 days]`. This represents how long the bond
will last until the user can withdraw. When a user stakes, an NFT representing their bond is minted to them. We also update
all of the yield rewards by skimming the fees from the sudoswap pool and transfer the LP tokens from the user's wallet into the contract.

**feeUnstake(uint256 tokenId)**

This unstakes a bond with a particular tokenId. It checks that the user owns the bond NFT they are trying to unstake and also
that the bond has matured/expired. Then we update all of the yield rewards by skimming the fees from the sudoswap pool and burn the 
bond NFT from the user's wallet. The LP tokens are transferred back to the user along with the fee rewards that they earned in 
yield.

**skim()**

Skims any surplus fees generated from the shared sudoswap xyk pool and distributes it to stakers.