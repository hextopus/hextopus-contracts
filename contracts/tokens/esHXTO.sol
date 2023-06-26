// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "../interfaces/IERC20.sol";

contract esHXTO is IERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public override totalSupply;

    address public gov;

    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowances;

    mapping (address => bool) public isMinter;
    mapping (address => bool) public isHandler;

    modifier onlyGov() {
        require(msg.sender == gov, "BaseToken: forbidden");
        _;
    }

    modifier onlyMinter() {
        require(isMinter[msg.sender], "MintableBaseToken: forbidden");
        _;
    }

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        gov = msg.sender;
    }

    function setMinter(address _minter, bool _isActive) external onlyGov {
        isMinter[_minter] = _isActive;
    }

    function setGov(address _gov) external onlyGov {
        gov = _gov;
    }

    function setInfo(string memory _name, string memory _symbol) external onlyGov {
        name = _name;
        symbol = _symbol;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).transfer(_account, _amount);
    }

    function setHandler(address _handler, bool _isActive) external onlyGov {
        isHandler[_handler] = _isActive;
    }

    function balanceOf(address _account) external view override returns (uint256) {
        return balances[_account];
    }

    function transfer(address _recipient, uint256 _amount) external override returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) external override returns (bool) {
        if (isHandler[msg.sender]) {
            _transfer(_sender, _recipient, _amount);
            return true;
        }

        uint256 nextAllowance = allowances[_sender][msg.sender] - _amount;

        _approve(_sender, msg.sender, nextAllowance);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) external view override returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount) external override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function mint(address _account, uint256 _amount) external onlyMinter {
        require(_account != address(0), "BaseToken: mint to the zero address");

        totalSupply = totalSupply + _amount;
        balances[_account] = balances[_account] + _amount;

        emit Transfer(address(0), _account, _amount);
    }

    function burn(address _account, uint256 _amount) external onlyMinter{
        require(_account != address(0), "BaseToken: burn from the zero address");

        balances[_account] = balances[_account] - _amount;
        totalSupply = totalSupply - _amount;

        emit Transfer(_account, address(0), _amount);
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) private {
        if(!isHandler[_sender]){
            require(isHandler[_recipient], "esHXTO: can not be transferred");
        }

        require(_sender != address(0), "BaseToken: transfer from the zero address");
        require(_recipient != address(0), "BaseToken: transfer to the zero address");

        balances[_sender] = balances[_sender] - _amount;
        balances[_recipient] = balances[_recipient] + _amount;

        emit Transfer(_sender, _recipient,_amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) private {
        require(_owner != address(0), "BaseToken: approve from the zero address");
        require(_spender != address(0), "BaseToken: approve to the zero address");

        allowances[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);
    }
}
