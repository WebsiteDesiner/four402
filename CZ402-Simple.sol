// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title CZ402 Charity Protocol
 * @dev BSC402.fourmeme × CZ Charity Payment
 * 402慈善支付协议 - 100% Fair Launch
 */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract CZ402 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    string public constant name = "CZ402";
    string public constant symbol = "CZ402";
    uint8 public constant decimals = 18;
    
    uint256 private _totalSupply;
    uint256 public constant MAX_SUPPLY = 1000000000 * 10**18; // 1B
    
    // Core Protocol
    address public constant CZ_ADDRESS = 0x28816C4c4792467390C90E5b426F198570E29307;
    address public immutable bsc402Token;
    uint256 public constant RATIO = 10; // 10 BSC402 = 1 CZ402
    
    // Statistics
    uint256 public totalDonated;
    uint256 public totalDonors;
    uint256 public donationCount;
    
    mapping(address => uint256) public donorAmount;
    mapping(address => uint256) public donorTimes;
    
    // Events
    event Donation(address indexed donor, uint256 bsc402Amount, uint256 cz402Amount);
    
    constructor(address _bsc402) {
        bsc402Token = _bsc402;
    }
    
    function donate(uint256 amount) external {
        require(amount >= RATIO * 10**18, "Min 10 BSC402");
        require(_totalSupply + (amount / RATIO) <= MAX_SUPPLY, "Max supply");
        
        // Transfer BSC402 to CZ
        require(
            IERC20(bsc402Token).transferFrom(msg.sender, CZ_ADDRESS, amount),
            "Transfer failed"
        );
        
        // Update stats
        if (donorAmount[msg.sender] == 0) {
            totalDonors++;
        }
        
        uint256 cz402Amount = amount / RATIO;
        
        donorAmount[msg.sender] += amount;
        donorTimes[msg.sender]++;
        totalDonated += amount;
        donationCount++;
        
        // Mint CZ402
        _mint(msg.sender, cz402Amount);
        
        emit Donation(msg.sender, amount, cz402Amount);
    }
    
    function getDonorInfo(address donor) external view returns (
        uint256 donated,
        uint256 times,
        uint256 cz402Balance
    ) {
        return (
            donorAmount[donor],
            donorTimes[donor],
            _balances[donor]
        );
    }
    
    function getStats() external view returns (
        uint256 raised,
        uint256 donors,
        uint256 donations,
        uint256 minted
    ) {
        return (totalDonated, totalDonors, donationCount, _totalSupply);
    }
    
    // Standard ERC20
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "Allowance exceeded");
        
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, currentAllowance - amount);
        
        return true;
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "Zero address");
        require(recipient != address(0), "Zero address");
        
        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "Insufficient balance");
        
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;
        
        emit Transfer(sender, recipient, amount);
    }
    
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "Zero address");
        
        _totalSupply += amount;
        _balances[account] += amount;
        
        emit Transfer(address(0), account, amount);
    }
    
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Zero address");
        require(spender != address(0), "Zero address");
        
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

/**
 * Deploy Instructions:
 * 1. Deploy with BSC402 token address: 0x55e6587510C6c2cbeA7140ab1c16Db0fa2aE8c1A
 * 2. Users approve BSC402 to this contract
 * 3. Users call donate() with BSC402 amount
 * 
 * BSC Testnet Example:
 * BSC402: 0x55e6587510C6c2cbeA7140ab1c16Db0fa2aE8c1A (replace with actual)
 * CZ402: [Deploy this contract]
 * 
 * Mainnet:
 * BSC402: [FourMeme402 address on BSC]
 * CZ402: [Deploy this contract on BSC]
 */
