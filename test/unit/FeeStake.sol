// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../Fixture.t.sol";

contract FeeStakeTest is Fixture {
    uint96 public amount;

    function setUp() public {
        amount = 100;
        deal(address(lp), address(this), amount);
    }

    function testItBurnsLpTokens() public {
        // arrange
        uint256 balanceBefore = lp.balanceOf(address(this));

        // act
        w.feeStake(amount, 0);

        // assert
        assertEq(balanceBefore - lp.balanceOf(address(this)), amount, "Should have burned lp tokens");
    }

    function testItUpdatesTotalStakedSupply() public {
        // arrange
        uint256 termIndex = 1;
        uint256 termBooster = w.termBoosters(termIndex);

        // act
        w.feeStake(amount, termIndex);

        // assert
        assertEq(w.feeStakedTotalSupply(), (amount * termBooster) / 1e18, "Should have updated staked total supply");
    }

    function testItSavesBondDetails() public {
        // arrange
        uint256 tokenId = w.feeStake(amount, 1);

        // assert
        assertEq(w.feeBonds(tokenId).termIndex, 1, "Should have saved bond term index");
        assertEq(w.feeBonds(tokenId).depositTimestamp, block.timestamp, "Should have saved bond deposit timestamp");
        assertEq(w.feeBonds(tokenId).depositAmount, amount, "Should have saved bond deposit amount");
        assertEq(
            w.feeBonds(tokenId).rewardPerTokenCheckpoint, 0, "Should have inited staked bond reward per token paid"
        );
    }

    function testItSetsBondRewardPerTokenCheckpointAndRewardPerTokenStored() public {
        // arrange
        uint256 rewardAmount = 0.001 ether;
        w.feeStake(amount, 1);
        deal(address(lp), address(this), amount);
        payable(address(pair)).transfer(rewardAmount);
        uint256 expectedRewardPerTokenPaid = (rewardAmount * 1e18) / ((amount * w.termBoosters(1)) / 1e18);

        // act
        uint256 tokenId = w.feeStake(amount, 1);

        // assert
        assertEq(w.feeRewardPerTokenStored(), expectedRewardPerTokenPaid, "Should have stored reward per token");
        assertEq(
            w.feeBonds(tokenId).rewardPerTokenCheckpoint,
            expectedRewardPerTokenPaid,
            "Should have updated staked bond reward per token paid"
        );
    }

    function testItMintsBondNft() public {
        // arrange
        uint256 tokenId = w.feeStake(amount, 1);

        // assert
        assertEq(feeB.ownerOf(tokenId), address(this), "Should have minted bond NFT");
        assertEq(w.feeTotalBondSupply(), 1, "Should incremented total bond supply");
    }
}
