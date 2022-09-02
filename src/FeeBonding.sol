// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {PuttyV2} from "putty-v2/PuttyV2.sol";
import {LSSVMPairMissingEnumerableETH} from "lssvm/LSSVMPairMissingEnumerableETH.sol";

import {MintBurnToken} from "./MintBurnToken.sol";
import {BondingNft} from "./BondingNft.sol";

contract FeeBonding {
    /**
     * @notice Bond details.
     * @param rewardPerTokenCheckpoint The total rewards per token at bond creation.
     * @param depositAmount The amount of lp tokens deposited into the bond.
     * @param depositTimestamp The unix timestamp of the deposit.
     * @param termIndex The index into the terms array for the bond term.
     */
    struct FeeBond {
        uint256 rewardPerTokenCheckpoint;
        uint96 depositAmount;
        uint32 depositTimestamp;
        uint8 termIndex;
    }

    /// @notice The term duration options for bonds.
    uint256[] private terms = [0 days, 7 days, 30 days, 90 days, 180 days, 365 days];

    /// @notice The yield boost options for corresponding to each term.
    uint256[] private termBoosters = [1e18, 1.1e18, 1.2e18, 1.5e18, 2e18, 3e18];

    /// @notice The last calculated amount of rewards per token.
    uint256 public feeRewardPerTokenStored;

    /// @notice The total amount of bonds in existence.
    uint32 public feeTotalBondSupply;

    /// @notice The total amount of synthetic supply being staked.
    /// @dev Calculated by summing total lp tokens staked * yield booster.
    uint96 public feeStakedTotalSupply;

    /// @notice The nft contract that represents bonds.
    BondingNft public immutable feeBondingNft;

    /// @notice The ERC20 token that represents lp shares in the sudoswap pool.
    MintBurnToken private immutable lpToken;

    /// @notice The sudoswap pool.
    LSSVMPairMissingEnumerableETH private pair;

    /// @notice Mapping of bondId to bond details.
    mapping(uint256 => FeeBond) private _bonds;

    constructor(address _lpToken) {
        lpToken = MintBurnToken(_lpToken);
        feeBondingNft = new BondingNft();
    }

    /**
     * @notice Sets the sudoswap pool address.
     * @param _pair The sudoswap pool.
     */
    function _setPair(address payable _pair) internal {
        pair = LSSVMPairMissingEnumerableETH(_pair);
    }

    /**
     * @notice Skims the fees from the sudoswap pool and distributes them to fee stakers.
     */
    function skim() public returns (uint256) {
        // skim the fees
        uint256 fees = address(pair).balance - pair.spotPrice();
        pair.withdrawETH(fees);

        // distribute the fees to stakers
        feeRewardPerTokenStored += feeStakedTotalSupply > 0 ? (fees * 1e18) / feeStakedTotalSupply : 0;

        return fees;
    }

    /**
     * @notice stakes an amount of lp tokens for a given term.
     * @param amount amount of lp tokens to stake.
     * @param termIndex index into the terms array which tells how long to stake for.
     */
    function feeStake(uint96 amount, uint256 termIndex) public returns (uint256 tokenId) {
        // update the rewards for everyone
        skim();

        // mint the bond
        feeTotalBondSupply += 1;
        tokenId = feeTotalBondSupply;
        feeBondingNft.mint(msg.sender, tokenId);

        // set the bond parameters
        FeeBond storage bond = _bonds[tokenId];
        bond.rewardPerTokenCheckpoint = uint256(feeRewardPerTokenStored);
        bond.depositAmount = amount;
        bond.depositTimestamp = uint32(block.timestamp);
        bond.termIndex = uint8(termIndex);

        // update the staked total supply
        feeStakedTotalSupply += uint96((uint256(amount) * termBoosters[termIndex]) / 1e18);

        // transfer lp tokens from sender
        lpToken.transferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice unstakes a bond, returns lp tokens and mints call option tokens.
     * @param tokenId the tokenId of the bond to unstake.
     */
    function feeUnstake(uint256 tokenId) public returns (uint256 rewardAmount) {
        // check that the user owns the bond
        require(msg.sender == feeBondingNft.ownerOf(tokenId), "Not owner");

        // check that the bond has matured
        FeeBond memory bond = _bonds[tokenId];
        require(block.timestamp >= bond.depositTimestamp + terms[bond.termIndex], "Bond not matured");

        // update the rewards for everyone
        skim();

        // burn the bond
        feeBondingNft.burn(tokenId);

        // update staked total supply
        uint256 amount = bond.depositAmount;
        feeStakedTotalSupply -= uint96((amount * termBoosters[bond.termIndex]) / 1e18);

        // send lp tokens back to sender
        lpToken.transfer(msg.sender, amount);

        // send fee rewards to sender
        rewardAmount = feeEarned(tokenId);
        payable(msg.sender).transfer(rewardAmount);
    }

    /**
     * @notice Calculates how much fees a bond has earned.
     * @param tokenId The tokenId to fetch earned info for.
     * @return earned How much fees the bond has earned.
     */
    function feeEarned(uint256 tokenId) public view returns (uint256) {
        FeeBond storage bond = _bonds[tokenId];
        uint256 amount = bond.depositAmount;

        return (
            ((amount * termBoosters[bond.termIndex]) / 1e18) * (feeRewardPerTokenStored - bond.rewardPerTokenCheckpoint)
        ) / 1e18;
    }

    /**
     * @notice Getter for bond details.
     * @param tokenId The tokenId to fetch info for.
     * @return bondDetails The bond details.
     */
    function feeBonds(uint256 tokenId) public view returns (FeeBond memory) {
        return _bonds[tokenId];
    }
}
