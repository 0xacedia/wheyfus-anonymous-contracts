# helo welcome to Wheyfus anonymous :3

Shared sudoswap LPing, bonding, staking and call option farming. hrehehehe.

Ok pls allow me to take u through a tour of the contracts.

```
forge install
forge test
```

It works like this. Mint some wheyfus (symbol: "UwU"). 
LP them into a shared sudoswap pool with equal parts eth and wheyfus.
Receive LP tokens representing ur share in the pool. 
Bond those LP tokens for a fixed term.
At the end of the term, claim your zero-coupon bond, receive LP tokens that you initially deposited + some call option ERC20 tokens.
Convert ERC20 call options into an actual call option (done via putty).
The strike is amount of wheyfus in contract * 0.1 ether. The expiration is in 5 years.
Exercise your call option, send 0.1 ether * wheyfu amount and receive N wheyfus.
You can boost your call option erc20 yield by bonding for longer term durations.
Got it? noice.

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

Finance stuff is cool. but gym girls (2d) are cooler. they are so fucking tight and muscular and HOT. gosh.
Sometimes i look at them and justt think about how THICK and juicy they can get. imagine a wheyfu crushing ur head between her legs. damn.

<img src="./assets/wheyfu1.jpeg" alt="wheyfu1" width="300"/>
