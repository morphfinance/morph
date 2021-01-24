// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './ownable.sol';

contract Operator is Context, Ownable {
    address private _operator;
    mapping (address => bool) private privileged;

    event OperatorTransferred(
        address indexed previousOperator,
        address indexed newOperator
    );

    constructor() internal {
        _operator = _msgSender();
        emit OperatorTransferred(address(0), _operator);
    }

    function operator() public view returns (address) {
        return _operator;
    }
    
    function setPrivileged(address _usr, bool _isPrivileged) public onlyOwner { // This allows for multiple contracts to call the functions, such is needed for migrator and treasury to burn MORC and other tokens simultaniously 
        privileged[_usr] = _isPrivileged;
    }

    modifier onlyOperator() {
        require(msg.sender == _operator || privileged[msg.sender] == true, 'operator: caller does not have permission');
        _;
    }

    function isOperator() public view returns (bool) {
        return _msgSender() == _operator;
    }

    function transferOperator(address newOperator_) public onlyOwner {
        _transferOperator(newOperator_);
    }

    function _transferOperator(address newOperator_) internal {
        require(
            newOperator_ != address(0),
            'operator: zero address given for new operator'
        );
        emit OperatorTransferred(address(0), newOperator_);
        _operator = newOperator_;
    }
}
