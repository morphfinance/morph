// SPDX-License-Identifier: CC-BY-NC-SA-2.5

//@code0x2

pragma solidity ^0.6.12;

import './files/context.sol';
import './files/ierc20.sol';
import './files/operator.sol';
import './files/iuniswap.sol';
import './files/address.sol';

interface IOptimizer {
    function allocateSeigniorage(uint256 amount) external;
    function allocateFee(uint256 amount) external;
}

contract LimitedERC20 is Context, IERC20Standard {
    using SafeMath for uint256;
    using Address for address;
    address public feeManager;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    uint256 internal burnShare = 75;

    constructor (string memory name, string memory symbol, address _feeManager) public {
        _name = name;
        _symbol = symbol;
        _decimals = 18;
        feeManager = _feeManager;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        (address feeReceiver, uint256 feeAmount) = IFeeManager(feeManager).queryFee(sender, recipient, amount);
        _balances[sender] = _balances[sender].sub(amount, 'ERC20: transfer amount exceeds balance');

        if(feeAmount > 0) { // Fee share should be set to zero, and an external fee allocator should be used. fixes double burn bug
            uint256 burnAmount = feeAmount.mul(burnShare).div(100);
            _balances[feeReceiver] = _balances[feeReceiver].add(feeAmount.sub(burnAmount));
            IOptimizer(feeReceiver).allocateFee(feeAmount.sub(burnAmount));
            emit Transfer(sender, feeReceiver, feeAmount.sub(burnAmount));
            _burn(sender, burnAmount);
        }

        amount = amount.sub(feeAmount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    function _setFeeManager(address _fmg) internal {
        feeManager = _fmg;
    }

    function _setBurnShare(uint256 _toBurn) internal {
        burnShare = _toBurn;
    }
}

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
        _burn(account, amount);
    }
}

contract morphCoin is ERC20Burnable, Operator {

    constructor(address _feeManager) public LimitedERC20('Morph Coin', 'MORC', _feeManager) {
    }

    function mint(address recipient_, uint256 amount_)
        public
        onlyOperator
        returns (bool)
    {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);

        return balanceAfter > balanceBefore;
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

    function setBurnShare(uint256 _toBurn) public onlyOwner {
        _setBurnShare(_toBurn);
    }

    // Fallback rescue

    receive() external payable{
        payable(owner()).transfer(msg.value);
    }

    function rescueToken(IERC20 _token) public {
        _token.transfer(owner(), _token.balanceOf(address(this)));
    }
}
