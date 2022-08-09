// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "solmate/tokens/ERC20.sol";
import "solmate/auth/Owned.sol";

contract MintBurnToken is ERC20, Owned {
    mapping(address => bool) public whitelistedMinterBurner;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20(_name, _symbol, _decimals) Owned(msg.sender) {}

    modifier onlyMinterBurner() virtual {
        require(whitelistedMinterBurner[msg.sender], "UNAUTHORIZED");
        _;
    }

    function setMinterBurner(address target, bool authorized) public onlyOwner {
        whitelistedMinterBurner[target] = authorized;
    }

    function mint(address to, uint256 amount) public onlyMinterBurner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyMinterBurner {
        _burn(from, amount);
    }
}
