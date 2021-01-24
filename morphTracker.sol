// SPDX-License-Identifier: CC-BY-NC-SA-2.5

//@code0x2

pragma solidity ^0.6.12;

import './files/erc20.sol';
import './files/operator.sol';
import './files/limitederc20.sol';

abstract contract ERC20Burnable is Context, LimitedERC20 {
    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        uint256 decreasedAllowance = allowance(account, _msgSender()).sub(amount, "ERC20: burn amount exceeds allowance");

        _approve(account, _msgSender(), decreasedAllowance);
        _burn(account, amount);
    }
}

contract morphTracker is ERC20Burnable, Operator {
    
    constructor(address _feeManager) public LimitedERC20('Morph Tracker', 'MORT', _feeManager) {
    }

    /**
     * @notice Operator mints ONSis cash to a recipient
     * @param recipient_ The address of recipient
     * @param amount_ The amount of ONSis cash to mint to
     */
    function mint(address recipient_, uint256 amount_)
        public
        onlyOperator
        returns (bool)
    {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);
        return balanceAfter >= balanceBefore;
    }

    function burn(uint256 amount) public override onlyOperator {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount)
        public
        override
        onlyOperator
    {
        super.burnFrom(account, amount);
    }
    
    function setFeeManager(address _feeManager) public onlyOwner {
        _setFeeManager(_feeManager);
    }
    
    // Fallback rescue
    
    receive() external payable{
        payable(owner()).transfer(msg.value);
    }
    
    function rescueToken(IERC20 _token) public {
        _token.transfer(owner(), _token.balanceOf(address(this)));
    }
}
