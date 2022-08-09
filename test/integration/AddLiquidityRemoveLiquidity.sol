// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

import "../Fixture.t.sol";

contract AddLiquidityRemoveLiquidityTest is Fixture, ERC721TokenReceiver {
    using stdStorage for StdStorage;

    uint256[] public tokenIds;

    receive() external payable {}

    function setUp() public {}

    function testAddRemove(uint8[] memory depositsNumNfts) public {
        uint256 maxIndex;
        uint256[] memory deposits = new uint256[](depositsNumNfts.length);

        for (uint256 i = 0; i < depositsNumNfts.length; i++) {
            depositsNumNfts[i] = uint8(Math.max(depositsNumNfts[i], 1));
        }

        for (uint256 i = 0; i < depositsNumNfts.length; i++) {
            if (
                w.totalSupply() + depositsNumNfts[i] >=
                w.mintWhitelist(address(this))
            ) {
                vm.stopPrank();
                break;
            }

            address person = address(uint160(type(uint256).max - i));
            w.whitelistMinter(person, depositsNumNfts[i]);
            vm.startPrank(person);

            delete tokenIds;

            uint256 totalSupplyBefore = w.totalSupply();
            uint256 mintAmount = depositsNumNfts[i];
            w.mint(mintAmount);

            for (
                uint256 i = totalSupplyBefore;
                i < totalSupplyBefore + mintAmount;
                i++
            ) {
                tokenIds.push(i + 1);
            }

            uint256 price = w.price() == 0 ? 1 ether : w.price();
            uint256 deposit = price * tokenIds.length;
            deposits[i] = deposit;
            deal(person, deposit);
            w.addLiquidity{value: deposit}(tokenIds, 0, type(uint256).max);
            vm.stopPrank();

            maxIndex = i + 1;
        }

        uint256 ij = 0;
        for (uint256 i = 0; i < maxIndex; i++) {
            address person = address(uint160(type(uint256).max - i));
            vm.startPrank(person);

            delete tokenIds;
            for (uint256 j = 0; j < depositsNumNfts[i]; j++) {
                ij += 1;
                tokenIds.push(ij);
            }

            if (tokenIds.length != 0) {
                w.removeLiquidity(tokenIds, 0, type(uint256).max);
            }
            vm.stopPrank();

            assertEq(
                person.balance,
                deposits[i],
                "Should have withdrawn liquidity"
            );

            for (uint256 k = 0; k < tokenIds.length; k++) {
                assertEq(
                    w.ownerOf(tokenIds[k]),
                    person,
                    "Should have withdrawn NFT"
                );
            }
        }

        assertEq(lp.totalSupply(), 0, "Should have burned all LP tokens");
        assertEq(w.tokenReserves(), 0, "Should have updated ETH reserves");
        assertEq(w.nftReserves(), 0, "Should have updated NFT reserves");
        assertEq(
            address(w.pair()).balance,
            0,
            "Should have withdrawn all ETH liq"
        );
        assertEq(
            w.balanceOf(address(w.pair())),
            0,
            "Should have withdrawn all NFT liq"
        );
    }
}
