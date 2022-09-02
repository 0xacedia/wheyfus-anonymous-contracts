// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {PuttyV2} from "putty-v2/PuttyV2.sol";

import {MintBurnToken} from "./MintBurnToken.sol";
import {BondingNft} from "./BondingNft.sol";

contract OptionBonding is IERC1271, Owned {
    /**
     * @notice Bond details.
     * @param rewardPerTokenCheckpoint The total rewards per token at bond creation.
     * @param depositAmount The amount of lp tokens deposited into the bond.
     * @param depositTimestamp The unix timestamp of the deposit.
     * @param termIndex The index into the terms array for the bond term.
     */
    struct Bond {
        uint256 rewardPerTokenCheckpoint;
        uint96 depositAmount;
        uint32 depositTimestamp;
        uint8 termIndex;
    }

    /// @notice The term duration options for bonds.
    uint256[] public terms = [0, 7 days, 30 days, 90 days, 180 days, 365 days];

    /// @notice The yield boost options for corresponding to each term.
    uint256[] public termBoosters = [1e18, 1.1e18, 1.2e18, 1.5e18, 2e18, 3e18];

    /// @notice The ERC20 token that can be used to claim call options.
    MintBurnToken public immutable callOptionToken;

    /// @notice The ERC20 token that represents lp shares in the sudoswap pool.
    MintBurnToken public immutable lpToken;

    /// @notice The nft contract that represents bonds.
    BondingNft public immutable bondingNft;

    /// @notice The Putty contract.
    PuttyV2 public immutable putty;

    /// @notice The Wrapped Ethereum contract.
    IERC20 public immutable weth;

    /// @notice The total amount of call option tokens to give out in bond rewards.
    uint256 public constant TOTAL_REWARDS = 9000 * 1e18;

    /// @notice The duration over which bond rewards are distributed.
    uint256 public constant REWARD_DURATION = 900 days;

    /// @notice The strike price for each call option.
    uint256 public constant STRIKE = 0.1 ether;

    /// @notice The emission rate for call option tokens.
    /// @dev Calculated by taking the total rewards and dividing it by the reward duration.
    uint256 public immutable rewardRate = TOTAL_REWARDS / REWARD_DURATION;

    /// @notice The expiration date of each option.
    /// @dev The expiration date is set to be 1825 days from the deployment date (approx. 5 years).
    uint256 public immutable optionExpiration = block.timestamp + 1825 days;

    /// @notice The date at which rewards will stop being distributed.
    /// @dev Set to be the deploy timestamp + the reward duration.
    uint256 public immutable finishAt = block.timestamp + REWARD_DURATION;

    /// @notice The date at which rewards started being distributed.
    uint256 public immutable startAt = block.timestamp;

    /// @notice The total amount of bonds in existence.
    uint32 public totalBondSupply;

    /// @notice The last time at which staking rewards were calculated.
    uint32 public lastUpdateTime = uint32(block.timestamp);

    /// @notice The total amount of synthetic supply being staked.
    /// @dev Calculated by summing total lp tokens staked * yield booster.
    uint96 public stakedTotalSupply;

    /// @notice The last calculated amount of rewards per token.
    uint256 public rewardPerTokenStored;

    /// @notice Mapping of bondId to bond details.
    mapping(uint256 => Bond) private _bonds;

    /**
     * @notice Emitted when LP tokens are staked.
     * @param bondId The tokenId of the new bond.
     * @param bond The bond details.
     */
    event Stake(uint256 bondId, Bond bond);

    /**
     * @notice Emitted when LP tokens are unstaked.
     * @param bondId The tokenId of the bond being unstaked.
     * @param bond The bond details.
     */
    event Unstake(uint256 bondId, Bond bond);

    constructor(address _lpToken, address _callOptionToken, address _putty, address _weth) Owned(msg.sender) {
        lpToken = MintBurnToken(_lpToken);
        callOptionToken = MintBurnToken(_callOptionToken);
        putty = PuttyV2(_putty);
        weth = IERC20(_weth);
        bondingNft = new BondingNft();
    }

    /**
     * STAKING FUNCTIONS
     */

    /**
     * @notice stakes an amount of lp tokens for a given term.
     * @param amount amount of lp tokens to stake.
     * @param termIndex index into the terms array which tells how long to stake for.
     */
    function stake(uint96 amount, uint256 termIndex) public returns (uint256 tokenId) {
        // mint the bond
        totalBondSupply += 1;
        tokenId = totalBondSupply;
        bondingNft.mint(msg.sender, tokenId);

        // update the rewards for everyone
        rewardPerTokenStored = uint256(rewardPerToken());

        // set the bond parameters
        Bond storage bond = _bonds[tokenId];
        bond.rewardPerTokenCheckpoint = uint256(rewardPerTokenStored);
        bond.depositAmount = amount;
        bond.depositTimestamp = uint32(block.timestamp);
        bond.termIndex = uint8(termIndex);

        // update last update time and staked total supply
        lastUpdateTime = uint32(block.timestamp);
        stakedTotalSupply += uint96((uint256(amount) * termBoosters[termIndex]) / 1e18);

        // transfer lp tokens from sender
        lpToken.transferFrom(msg.sender, address(this), amount);

        emit Stake(tokenId, bond);
    }

    /**
     * @notice unstakes a bond, returns lp tokens and mints call option tokens.
     * @param tokenId the tokenId of the bond to unstake.
     */
    function unstake(uint256 tokenId) public returns (uint256 callOptionAmount) {
        // check that the user owns the bond
        require(msg.sender == bondingNft.ownerOf(tokenId), "Not owner");

        // check that the bond has matured
        Bond memory bond = _bonds[tokenId];
        require(block.timestamp >= bond.depositTimestamp + terms[bond.termIndex], "Bond not matured");

        // burn the bond
        bondingNft.burn(tokenId);

        // update the rewards for everyone
        rewardPerTokenStored = uint256(rewardPerToken());

        // update last update time and staked total supply
        lastUpdateTime = uint32(block.timestamp);
        uint256 amount = bond.depositAmount;
        stakedTotalSupply -= uint96((amount * termBoosters[bond.termIndex]) / 1e18);

        // send lp tokens back to sender
        lpToken.transfer(msg.sender, amount);

        // mint call option rewards to sender
        callOptionAmount = earned(tokenId);
        callOptionToken.mint(msg.sender, callOptionAmount);

        emit Unstake(tokenId, bond);
    }

    function rewardPerToken() public view returns (uint256) {
        if (stakedTotalSupply == 0) {
            return rewardPerTokenStored;
        }

        uint256 delta = Math.min(block.timestamp, finishAt) - Math.min(lastUpdateTime, finishAt);

        return rewardPerTokenStored + ((delta * rewardRate * 1e18) / stakedTotalSupply);
    }

    function earned(uint256 tokenId) public view returns (uint256) {
        Bond storage bond = _bonds[tokenId];
        uint256 amount = bond.depositAmount;

        return (((amount * termBoosters[bond.termIndex]) / 1e18) * (rewardPerToken() - bond.rewardPerTokenCheckpoint))
            / 1e18;
    }

    /**
     * OPTION FUNCTIONS
     */

    /**
     * @notice burns call option tokens and converts them into an actual call option contract via putty.
     * @param numAssets the amount of assets to put into the call option.
     * @param nonce the nonce for the call option (prevents hash collisions).
     */
    function convertToOption(uint256 numAssets, uint256 nonce)
        public
        returns (uint256 longTokenId, PuttyV2.Order memory shortOrder)
    {
        require(numAssets > 0, "Must convert at least one asset");
        require(numAssets <= 50, "Must convert 50 or less assets");

        // set the option parameters
        shortOrder.maker = address(this);
        shortOrder.isCall = true;
        shortOrder.isLong = false;
        shortOrder.baseAsset = address(weth);
        shortOrder.strike = STRIKE * numAssets;
        shortOrder.duration = optionExpiration - block.timestamp;
        shortOrder.expiration = block.timestamp + 1;
        shortOrder.nonce = nonce;
        shortOrder.erc721Assets = new PuttyV2.ERC721Asset[](1);
        shortOrder.erc721Assets[0] = PuttyV2.ERC721Asset({token: address(this), tokenId: type(uint256).max - numAssets});

        // burn the call option tokens from the sender
        uint256 amount = numAssets * 1e18;
        callOptionToken.burn(msg.sender, amount);

        // mint the option and send the long option to the sender
        longTokenId = _mintOption(shortOrder);
        putty.transferFrom(address(this), msg.sender, longTokenId);
    }

    uint256 public mintingOption = 1;

    /**
     * @notice Whether or not an order from putty can be filled.
     * @dev This should only return true when mintingOption is set to 2.
     */
    function isValidSignature(bytes32, bytes memory) external view returns (bytes4 magicValue) {
        magicValue = mintingOption == 2 ? IERC1271.isValidSignature.selector : bytes4(0);
    }

    /**
     * @notice Mints a new putty option.
     * @param order The order details to mint.
     */
    function _mintOption(PuttyV2.Order memory order) internal returns (uint256 tokenId) {
        mintingOption = 2;
        uint256[] memory empty = new uint256[](0);
        bytes memory signature;

        tokenId = putty.fillOrder(order, signature, empty);
        mintingOption = 1;
    }

    /**
     * @notice withdraws the eth earned from exercised call options.
     * @param orders the orders/options that were exercised.
     * @param recipient who to send the weth to.
     */
    function withdrawWeth(PuttyV2.Order[] memory orders, address recipient) public onlyOwner {
        for (uint256 i = 0; i < orders.length; i++) {
            putty.withdraw(orders[i]);
        }

        weth.transfer(recipient, weth.balanceOf(address(this)));
    }

    /**
     * @notice Getter for bond details.
     * @param tokenId The tokenId to fetch info for.
     * @return bondDetails The bond details.
     */
    function bonds(uint256 tokenId) public view returns (Bond memory) {
        return _bonds[tokenId];
    }
}
