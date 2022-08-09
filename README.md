# helo welcome to Wheyfus anonymous :3

Shared sudoswap LPing, bonding, staking and call option farming.

<img src="./assets/wheyfu2.gif" alt="wheyfu2" width="50%"/>

Ok pls allow me to take u through a tour of the contracts.

```
forge install
forge test
```

Here's how it works (oopsie whoopsie fucki wuckie!):

* Step 1: You mint some wheyfu's
* Step 2: You look at the current sudoswap price. Take equal parts wheyfus and eth and LP them into a shared sudo pool.
* Step 3: Receive some LP tokens representing your share in the pool.
* Step 4: Take those LP tokens and bond them for a fixed term (1 day, 1 months, 3 months, 0.5 years, 1 year).
* Step 5: At the end of the bonding duration, you claim back your LP tokens plus some call option tokens for *MOARRR* wheyfus.
* Step 6: Convert those call option tokens into actual call options via putty (expiration: in 5 years, strike: 0.1 ether * N wheyfus).
* Step 7: Exercise the call options.
* Step 8: With your new wheyfus you can then go back to step 2.

\*blows kiss\* <sup>*teehee*</sup>


<img src="./assets/wheyfu3.gif" alt="wheyfu3" width="50%"/>

There are 4 main functions:

Wheyfu.sol:

* addLiquidity
* removeLiquidity

Bonding.sol:

* stake
* unstake
* convertToOption

And there are 2 periphery functions to make things easier:

* addLiquidityAndStake
* multiConvertToOption

Finance stuff is cool but gym girls (2d) are cooler. they are so fucking tight and muscular and HOT. gosh.
Sometimes i look at them and justt think about how THICK and juicy they can get. imagine a wheyfu crushing ur head between her legs. damn. girls that reside in the third dimensional plane are also hot. but there isnt really a comparison. nothing personal just an opinion.

<img src="./assets/wheyfu1.jpeg" alt="wheyfu1" width="300"/>
