// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {PuttyV2} from "putty-v2/PuttyV2.sol";

import {MintBurnToken} from "./MintBurnToken.sol";
import {BondingNft} from "./BondingNft.sol";

contract Bonding is IERC1271, Owned {
    event Stake(uint256 bondId, Bond bond);
    event Unstake(uint256 bondId, Bond bond);

    struct Bond {
        uint256 rewardPerTokenCheckpoint;
        uint96 depositAmount;
        uint32 depositTimestamp;
        uint8 termIndex;
    }

    uint256[] public terms = [1 days, 30 days, 90 days, 180 days, 365 days];
    uint256[] public termBoosters = [1e18, 1.2e18, 1.5e18, 2e18, 3e18];

    MintBurnToken public immutable callOptionToken;
    MintBurnToken public immutable lpToken;
    PuttyV2 public immutable putty;
    IERC20 public immutable weth;
    BondingNft public immutable bondingNft;

    uint256 public constant TOTAL_REWARDS = 9000 * 1e18;
    uint256 public constant REWARD_DURATION = 900 days;
    uint256 public constant STRIKE = 0.1 ether;
    uint256 public immutable rewardRate = TOTAL_REWARDS / REWARD_DURATION;
    uint256 public immutable optionExpiration = block.timestamp + 1825 days;
    uint256 public immutable finishAt = block.timestamp + REWARD_DURATION;
    uint256 public immutable startAt = block.timestamp;

    uint32 public totalBondSupply;
    uint32 public lastUpdateTime = uint32(block.timestamp);
    uint96 public stakedTotalSupply;
    uint256 public rewardPerTokenStored;

    mapping(uint256 => Bond) private _bonds;

    constructor(
        address _lpToken,
        address _callOptionToken,
        address _putty,
        address _weth
    ) Owned(msg.sender) {
        lpToken = MintBurnToken(_lpToken);
        callOptionToken = MintBurnToken(_callOptionToken);
        putty = PuttyV2(_putty);
        weth = IERC20(_weth);
        bondingNft = new BondingNft();
    }

    /**
            STAKING FUNCTIONS
     */

    /**
        @notice stakes an amount of lp tokens for a given term.
        @param amount amount of lp tokens to stake.
        @param termIndex index into the terms array which tells how long to stake for. 
     */
    function stake(uint96 amount, uint256 termIndex)
        public
        returns (uint256 tokenId)
    {
        tokenId = _stake(amount, termIndex, true);
    }

    function _stake(
        uint96 amount,
        uint256 termIndex,
        bool burnShares
    ) internal returns (uint256 tokenId) {
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
        stakedTotalSupply += uint96(
            (uint256(amount) * termBoosters[termIndex]) / 1e18
        );

        // temporarily burn lp tokens from sender (until withdrawal)
        if (burnShares) {
            lpToken.burn(msg.sender, amount);
        }

        emit Stake(tokenId, bond);
    }

    /**
        @notice unstakes a bond, returns lp tokens and mints call option tokens.
        @param tokenId the tokenId of the bond to unstake.
     */
    function unstake(uint256 tokenId)
        public
        returns (uint256 callOptionAmount)
    {
        require(msg.sender == bondingNft.ownerOf(tokenId), "Not owner");

        Bond memory bond = _bonds[tokenId];
        require(
            block.timestamp >= bond.depositTimestamp + terms[bond.termIndex],
            "Bond not matured"
        );

        // burn the bond
        bondingNft.burn(tokenId);

        // update the rewards for everyone
        rewardPerTokenStored = uint256(rewardPerToken());

        // update last update time and staked total supply
        lastUpdateTime = uint32(block.timestamp);
        uint256 amount = bond.depositAmount;
        stakedTotalSupply -= uint96(
            (amount * termBoosters[bond.termIndex]) / 1e18
        );

        // mint lp tokens back to sender
        lpToken.mint(msg.sender, amount);

        // mint call  option rewards to sender
        callOptionAmount = earned(tokenId);
        callOptionToken.mint(msg.sender, callOptionAmount);

        emit Stake(tokenId, bond);
    }

    function rewardPerToken() public view returns (uint256) {
        if (stakedTotalSupply == 0) {
            return rewardPerTokenStored;
        }

        uint256 delta = Math.min(block.timestamp, finishAt) -
            Math.min(lastUpdateTime, finishAt);

        return
            rewardPerTokenStored +
            ((delta * rewardRate * 1e18) / stakedTotalSupply);
    }

    function earned(uint256 tokenId) public view returns (uint256) {
        Bond storage bond = _bonds[tokenId];
        uint256 amount = bond.depositAmount;

        return
            (((amount * termBoosters[bond.termIndex]) / 1e18) *
                (rewardPerToken() - bond.rewardPerTokenCheckpoint)) / 1e18;
    }

    /**
            OPTION FUNCTIONS
     */

    /**
        @notice burns call option tokens and converts them into an actual call option contract via putty.
        @param numAssets the amount of assets to put into the call option.
        @param nonce the nonce for the call option (prevents hash collisions).
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
        shortOrder.erc721Assets[0] = PuttyV2.ERC721Asset({
            token: address(this),
            tokenId: type(uint256).max - numAssets
        });

        // mint the option and send the long option to the sender
        longTokenId = _mintOption(shortOrder);
        putty.transferFrom(address(this), msg.sender, longTokenId);

        // burn the call option tokens from the sender
        uint256 amount = numAssets * 1e18;
        callOptionToken.burn(msg.sender, amount);
    }

    /**
        @notice mints several call options (each contract can have a max of 50 assets). 
        @param numAssets the total amount of assets to put into the call options.
        @param nonces the nonces for each call option.
     */
    function multiConvertToOption(uint256 numAssets, uint256[] memory nonces)
        public
    {
        uint256 i = 0;
        while (numAssets > 0) {
            uint256 amount = Math.min(50, numAssets);
            convertToOption(amount, nonces[i]);
            numAssets -= amount;
            i += 1;
        }
    }

    uint256 public mintingOption = 1;

    function isValidSignature(bytes32, bytes memory)
        external
        view
        returns (bytes4 magicValue)
    {
        magicValue = mintingOption == 2
            ? IERC1271.isValidSignature.selector
            : bytes4(0);
    }

    function _mintOption(PuttyV2.Order memory order)
        internal
        returns (uint256 tokenId)
    {
        mintingOption = 2;
        uint256[] memory empty = new uint256[](0);
        bytes memory signature;
        tokenId = putty.fillOrder(order, signature, empty);
        mintingOption = 1;
    }

    /**
        @notice withdraws the eth earned from exercised call options.
        @param orders the orders/options that were exercised.
        @param recipient who to send the weth to.
     */
    function withdrawWeth(PuttyV2.Order[] memory orders, address recipient)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < orders.length; i++) {
            putty.withdraw(orders[i]);
        }

        weth.transfer(recipient, weth.balanceOf(address(this)));
    }

    function bonds(uint256 tokenId) public view returns (Bond memory) {
        return _bonds[tokenId];
    }
}
