pragma solidity >= 0.8.0;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {EnumerableSet} from "openzeppelin/utils/structs/EnumerableSet.sol";

contract ERC1155Owned is ERC1155, Owned {
    constructor() Owned(msg.sender) {}

    function mint(address to, uint256 id, uint256 amount) public onlyOwner {
        _mint(to, id, amount, "");
    }

    function burn(address to, uint256 id, uint256 amount) public onlyOwner {
        _burn(to, id, amount);
    }

    function uri(uint256 /*id*/ ) public pure override returns (string memory) {
        return "https://autofarm.network";
    }
}

abstract contract ReceiptsController {
    using EnumerableSet for EnumerableSet.UintSet;

    ERC1155Owned public immutable receiptToken;
    uint256 public totalUnlocking;
    uint256 public currentId;

    mapping(address => EnumerableSet.UintSet) internal userReceipts;

    constructor() {
        receiptToken = new ERC1155Owned();
    }

    function issueReceipt(address receiver, uint256 amount) internal virtual {
        totalUnlocking += amount;

        uint256 id = ++currentId;

        userReceipts[receiver].add(id);

        receiptToken.mint(receiver, id, amount);

        afterIssueReceipt(id, amount);
    }

    function _redeemReceipt(address owner, uint256 id) internal virtual returns (uint256 assets) {
        uint256 receiptBalance = receiptToken.balanceOf(owner, id);

        require((assets = unlockableAssets(id, receiptBalance)) != 0, "ZERO_ASSETS");

        totalUnlocking -= assets;

        receiptToken.burn(owner, id, assets);

        if (assets == receiptBalance) {
            userReceipts[owner].remove(id);
        }
    }

    function afterIssueReceipt(uint256 id, uint256 assets) internal virtual;
    function unlockableAssets(uint256 id, uint256 balance) internal view virtual returns (uint256);

    // https://docs.openzeppelin.com/contracts/4.x/api/utils#EnumerableSet-values-struct-EnumerableSet-Bytes32Set-
    // This operation will copy the entire storage to memory, which can be quite expensive.
    // This is designed to mostly be used by view accessors that are queried without any gas fees.
    function getUserReceiptIds(address owner) public view returns (uint256[] memory) {
        return userReceipts[owner].values();
    }
}

abstract contract LockingVault2 is ERC4626, ReceiptsController {
    using SafeTransferLib for ERC20;

    function _totalAssets() public view virtual returns (uint256);
    function totalAssets() public view override returns (uint256) {
        return _totalAssets() - totalUnlocking;
    }

    function redeemReceipt(uint256 id) public returns (uint256 assets) {
        assets = _redeemReceipt(msg.sender, id);
        asset.safeTransfer(msg.sender, assets);
    }

    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) {
                allowance[owner][msg.sender] = allowed - shares;
            }
        }

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        // asset.safeTransfer(receiver, assets);
        issueReceipt(receiver, assets);
    }

    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) {
                allowance[owner][msg.sender] = allowed - shares;
            }
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        // asset.safeTransfer(receiver, assets);
        issueReceipt(receiver, assets);
    }
}
