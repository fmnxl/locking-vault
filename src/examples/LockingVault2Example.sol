pragma solidity >= 0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {LockingVault2} from "../LockingVault2.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";

// contract Token is ERC20("TEST", "TEST", 18) {}

contract LockingVault2Example is LockingVault2 {
    uint256 public immutable unlockingPeriod;

    mapping(uint256 => uint256) lockUntil;

    constructor(ERC20 _asset, string memory _name, string memory _symbol, uint256 _unlockingPeriod)
        ERC4626(_asset, _name, _symbol)
    {
        unlockingPeriod = _unlockingPeriod;
    }

    function afterIssueReceipt(uint256 id, uint256 /* assets */ ) internal override {
        lockUntil[id] = block.timestamp + unlockingPeriod;
    }

    function unlockableAssets(uint256 id, uint256 balance) internal view override returns (uint256) {
        uint256 lockedUntil = lockUntil[id];
        require(lockedUntil > 0, "Receipt has not been unlocked");
        return block.timestamp >= lockedUntil ? balance : 0;
    }

    function _totalAssets() public view override returns (uint256) {
	    return asset.balanceOf(address(this));
    }
}
