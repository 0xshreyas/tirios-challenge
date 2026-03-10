pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //  
  // ------------------------------------------ //

  // IERC20
  mapping(address => mapping(address => uint256)) private _allowances;
  mapping(address => uint256) private _withdrawableDividends;
  address[] private _holders;
  mapping(address => uint256) private _holderIndex;

  function _updateHolderStatus(address account) internal {
      uint256 currentBalance = balanceOf[account];
      uint256 index = _holderIndex[account];
      if (currentBalance > 0 && index == 0) {
          _holders.push(account);
          _holderIndex[account] = _holders.length;
          } else if (currentBalance == 0 && index > 0) {
          uint256 lastIndex = _holders.length;
          address lastAccount = _holders[lastIndex - 1];
          _holders[index - 1] = lastAccount;
          _holderIndex[lastAccount] = index;
          _holders.pop();
          _holderIndex[account] = 0;
      }
  }


  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    require(balanceOf[msg.sender] >= value, "Insufficient balance");
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    _updateHolderStatus(msg.sender);
    _updateHolderStatus(to);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    _allowances[msg.sender][spender] = value;
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    require(balanceOf[from] >= value, "Insufficient balance");
    require(_allowances[from][msg.sender] >= value, "Insufficient allowance");
    _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    _updateHolderStatus(from);
    _updateHolderStatus(to);
    return true;
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "Must send ETH to mint");
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
    _updateHolderStatus(msg.sender);
  }

  function burn(address payable dest) external override {
    uint256 amountToBurn = balanceOf[msg.sender];
    require(amountToBurn > 0, "No tokens to burn");
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amountToBurn);
    _updateHolderStatus(msg.sender);
    (bool success, ) = dest.call{value: amountToBurn}("");
    require(success, "ETH transfer failed");
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return _holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    require(index > 0 && index <= _holders.length, "Index out of bounds");
    return _holders[index - 1];
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "Must send ETH to record dividend");
    require(totalSupply > 0, "No tokens in circulation");
    for (uint256 i = 0; i < _holders.length; i++) {
        address holder = _holders[i];
        uint256 share = msg.value.mul(balanceOf[holder]).div(totalSupply);
        _withdrawableDividends[holder] = _withdrawableDividends[holder].add(share);
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return _withdrawableDividends[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = _withdrawableDividends[msg.sender];
    require(amount > 0, "No dividends available");
    _withdrawableDividends[msg.sender] = 0;
    (bool success, ) = dest.call{value: amount}("");
    require(success, "ETH transfer failed");
  }
}