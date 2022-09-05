// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../Fixture.t.sol";

contract AddLiquidityAndFeeStakeTest is Fixture {
    using stdStorage for StdStorage;

    uint256[] public tokenIds;
    uint256 public mintAmount;

    function setUp() public {
        mintAmount = 10;
        w.mint(mintAmount);

        for (uint256 i = 0; i < mintAmount; i++) {
            tokenIds.push(i + 1);
        }
    }

    function testItSendsETHToSudo() public {
        // arrange
        uint256 deposit = 1 ether;

        // act
        w.addLiquidityAndFeeStake{value: deposit}(tokenIds, 0, 0, 1);

        // assert
        assertEq(address(pair).balance, deposit, "Should have transferred ETH to sudo");
    }

    function testItReceivesBondNft() public {
        // arrange
        uint256 deposit = 1 ether;

        // act
        uint256 tokenId = w.addLiquidityAndFeeStake{value: deposit}(tokenIds, 0, 0, 1);

        // assert
        assertEq(feeB.ownerOf(tokenId), address(this), "Should have minted bond nft to depositer");
    }
}
