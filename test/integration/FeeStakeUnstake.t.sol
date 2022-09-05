// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../Fixture.t.sol";

contract FeeStakeUnstakeTest is Fixture, ERC721TokenReceiver {
    struct Swap {
        bool isBuy;
        uint8 nftAmount;
    }

    struct Stake {
        uint96 amount;
        uint16 duration;
        Swap[] swaps;
    }

    receive() external payable {}

    function setUp() public {}

    function testFeeStakeUnstake(Stake[] memory stakes) public {
        w.mint(1);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        w.addLiquidity{value: 0.03 ether}(tokenIds, 0, 0.03 ether);

        uint256 stakesLength = bound(stakes.length, 0, 100);
        uint256[] memory withdrawalTimes = new uint256[](stakesLength);
        bool[] memory isWithdrawn = new bool[](stakesLength);

        // loop through the stakes
        for (uint256 i = 0; i < stakesLength; i++) {
            address person = address(uint160(type(uint256).max - i));
            vm.startPrank(person);

            Stake memory stake = stakes[i];

            // fee stake the amount
            deal(address(lp), person, stake.amount, true);
            uint256 tokenId = w.feeStake(stake.amount, 0);

            vm.stopPrank();

            assertEq(w.feeEarned(tokenId), 0, "Should not have earned any fees on initial stake");

            // loop through swaps
            uint256 swapsLength = bound(stake.swaps.length, 0, 100);
            uint256 totalEarnedFees = 0;
            for (uint256 j = 0; j < swapsLength; j++) {
                // buy/sell nftAmount
                address swapper = address(bytes20(keccak256(abi.encode(j))));
                uint256 inputFee = swap(stake.swaps[j], swapper);
                totalEarnedFees += inputFee;
            }

            assertEq(address(pair).balance - pair.spotPrice(), totalEarnedFees, "Should have accrued fees");

            if (totalEarnedFees > 0 && w.feeStakedTotalSupply() > 0) {
                uint256 rewardsPerTokenBefore = w.feeRewardPerTokenStored();
                w.skim();
                assertEq(
                    w.feeRewardPerTokenStored() - rewardsPerTokenBefore,
                    (totalEarnedFees * 1e18) / w.feeStakedTotalSupply(),
                    "Should have distributed fees"
                );
            }

            // save withdrawal time
            withdrawalTimes[i] = block.timestamp + stake.duration;

            // skip duration
            skip(15 days);

            // loop through withdrawal times
            for (uint256 k = 0; k <= i; k++) {
                if (withdrawalTimes[k] == 0) {
                    break;
                }

                // if block.timestamp > withdrawal time and not withdrawn already, withdraw stake
                if (block.timestamp > withdrawalTimes[k] && !isWithdrawn[k]) {
                    address person = address(uint160(type(uint256).max - i));
                    vm.startPrank(person);

                    w.feeUnstake(k + 1);

                    vm.stopPrank();

                    isWithdrawn[k] = true;
                }
            }

            assertGe(address(pair).balance, pair.spotPrice(), "Balance should be greater than virtual reserves");
        }
    }

    function swap(Swap memory swap, address from) public returns (uint256) {
        if (swap.isBuy) {
            if (w.balanceOf(address(pair)) < 2) {
                return 0;
            }

            swap.nftAmount = uint8(bound(swap.nftAmount, 1, w.balanceOf(address(pair)) - 1));

            if (swap.nftAmount == 0) {
                return 0;
            }

            vm.startPrank(from);
            (,,, uint256 inputValue,) = pair.getBuyNFTQuote(swap.nftAmount);
            deal(from, inputValue);

            uint256 tokenReservesBefore = pair.spotPrice();
            uint256 inputAmount =
                pair.swapTokenForAnyNFTs{value: inputValue}(swap.nftAmount, inputValue, from, false, address(0));
            vm.stopPrank();

            return ((pair.spotPrice() - tokenReservesBefore) * pair.fee()) / 1e18;
        } else {
            if (w.MAX_SUPPLY() - w.whitelistedSupply() == 0) {
                return 0;
            }

            swap.nftAmount = uint8(bound(swap.nftAmount, 1, Math.min(w.MAX_SUPPLY() - w.whitelistedSupply(), 20)));
            w.whitelistMinter(from, swap.nftAmount);

            vm.startPrank(from);
            uint256[] memory nftIds = new uint256[](swap.nftAmount);
            uint256 totalSupply = w.mint(swap.nftAmount);
            w.setApprovalForAll(address(pair), true);
            for (uint256 i = 0; i < swap.nftAmount; i++) {
                nftIds[i] = (totalSupply - swap.nftAmount) + i + 1;
            }

            (,,, uint256 outputAmount,) = pair.getSellNFTQuote(swap.nftAmount);
            uint256 tokenReservesBefore = pair.spotPrice();
            uint256 inputAmount = pair.swapNFTsForToken(nftIds, outputAmount, payable(from), false, address(0));
            vm.stopPrank();

            return ((tokenReservesBefore - pair.spotPrice()) * pair.fee()) / 1e18;
        }
    }
}
