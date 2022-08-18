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
* Step 4: Take those LP tokens and bond them for a fixed term.
* Step 5: At bond maturity, claim back your LP tokens + call option tokens for *MOARRR* wheyfus.
* Step 6: Convert those call option tokens into actual call options via putty.
* Step 7: Exercise the call options.
* Step 8: With your new wheyfus you can then go back to step 2.

\*blows kiss\* <sup>*teehee*</sup>

NB:
* The longer you bond, the higher your relative yield boost.
* Each option lasts for 5 years and has a strike of N wheyfus * 0.1 ether.
* 9000 wheyfus in the form of option contracts are distributed over 900 days.


<img src="./assets/wheyfu3.gif" alt="wheyfu3" width="100%"/>

There are 4 main functions:

Wheyfu.sol:

* addLiquidity
* removeLiquidity

Bonding.sol:

* stake
* unstake
* convertToOption

And there is 1 periphery functions to make things easier:

* addLiquidityAndStake