// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

contract FOURSAirdrop is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public hasClaimed;
    mapping(address => uint256) public claimableAmount;
    mapping(address => uint256) public claimedAmount;
    
    uint256 private _totalSupply;
    string public name = "FOURS Token";
    string public symbol = "FOURS";
    uint8 public decimals = 18;
    
    // Constants
    uint256 public constant MAX_SUPPLY = 1000000000 * 10**18; // 1 billion FOURS tokens
    uint256 public constant CLAIM_FEE = 4 * 10**18; // 4 FOUR402 tokens fee
    uint256 public constant CLAIM_PERCENTAGE = 1; // 0.001 = 0.1%
    uint256 public constant CLAIM_DIVISOR = 1000; // For 0.1% calculation
    uint256 public constant MIN_FOUR_BALANCE = 100 * 10**18; // Minimum 100 FOUR tokens to be eligible
    
    // Addresses
    address public constant GIGGLE_ACADEMY_ADDRESS = 0xC7f501D25Ea088aeFCa8B4b3ebD936aAe12bF4A4;
    address public immutable FOUR_TOKEN_ADDRESS; // FOUR token for checking balance
    address public immutable FOUR402_TOKEN_ADDRESS; // FOUR402 token for payment
    
    // State variables
    uint256 public totalClaimed;
    uint256 public totalClaimers;
    uint256 public remainingSupply;
    uint256 public totalDonated; // Total FOUR402 donated to Giggle Academy
    
    // Stats tracking
    uint256 public totalWhaleClaimers;    // 10,000+ FOUR holders
    uint256 public totalLargeClaimers;    // 5,000+ FOUR holders
    uint256 public totalMediumClaimers;   // 1,000+ FOUR holders
    uint256 public totalSmallClaimers;    // 500+ FOUR holders
    uint256 public totalBasicClaimers;    // 100+ FOUR holders
    
    uint256 public launchTime;
    uint256 public lastClaimTime;
    
    // Events
    event TokensClaimed(address indexed claimer, uint256 amount, uint256 fee, uint256 tier);
    event AirdropInitialized(uint256 totalSupply, uint256 timestamp);
    event DonationSent(address indexed from, uint256 amount);
    
    constructor(address _fourToken, address _four402Token) {
        require(_fourToken != address(0), "Invalid FOUR token address");
        require(_four402Token != address(0), "Invalid FOUR402 token address");
        
        FOUR_TOKEN_ADDRESS = _fourToken;
        FOUR402_TOKEN_ADDRESS = _four402Token;
        
        _totalSupply = MAX_SUPPLY;
        remainingSupply = MAX_SUPPLY;
        _balances[address(this)] = MAX_SUPPLY;
        launchTime = block.timestamp;
        
        emit Transfer(address(0), address(this), MAX_SUPPLY);
        emit AirdropInitialized(MAX_SUPPLY, block.timestamp);
    }
    
    // Calculate claimable amount based on FOUR token holdings
    function calculateClaimableAmount(address user) public view returns (uint256 amount, uint256 tier) {
        if (hasClaimed[user]) {
            return (0, 0);
        }
        
        uint256 fourBalance = IERC20(FOUR_TOKEN_ADDRESS).balanceOf(user);
        
        // Minimum balance requirement
        if (fourBalance < MIN_FOUR_BALANCE) {
            return (0, 0);
        }
        
        // Calculate based on holdings with tiered system
        uint256 baseAmount = MAX_SUPPLY * CLAIM_PERCENTAGE / CLAIM_DIVISOR; // 0.1% of total supply
        uint256 multiplier = 1;
        
        // Tier system based on FOUR holdings
        if (fourBalance >= 10000 * 10**18) {
            multiplier = 5; // 5x for whales (10,000+ FOUR)
            tier = 5;
        } else if (fourBalance >= 5000 * 10**18) {
            multiplier = 4; // 4x for large holders (5,000+ FOUR)
            tier = 4;
        } else if (fourBalance >= 1000 * 10**18) {
            multiplier = 3; // 3x for medium holders (1,000+ FOUR)
            tier = 3;
        } else if (fourBalance >= 500 * 10**18) {
            multiplier = 2; // 2x for small holders (500+ FOUR)
            tier = 2;
        } else {
            multiplier = 1; // 1x for basic holders (100+ FOUR)
            tier = 1;
        }
        
        amount = baseAmount * multiplier;
        
        // Cap at remaining supply
        if (amount > remainingSupply) {
            amount = remainingSupply;
        }
        
        return (amount, tier);
    }
    
    // Claim tokens by paying the fee in FOUR402
    function claimTokens() external returns (bool) {
        require(!hasClaimed[msg.sender], "Already claimed");
        
        (uint256 claimAmount, uint256 tier) = calculateClaimableAmount(msg.sender);
        require(claimAmount > 0, "Not eligible or no tokens to claim");
        require(remainingSupply >= claimAmount, "Insufficient remaining supply");
        
        // Check FOUR402 balance and allowance for payment
        IERC20 four402Token = IERC20(FOUR402_TOKEN_ADDRESS);
        require(four402Token.balanceOf(msg.sender) >= CLAIM_FEE, "Insufficient FOUR402 balance");
        require(four402Token.allowance(msg.sender, address(this)) >= CLAIM_FEE, "Insufficient FOUR402 allowance");
        
        // Transfer fee to Giggle Academy
        require(four402Token.transferFrom(msg.sender, GIGGLE_ACADEMY_ADDRESS, CLAIM_FEE), "Fee transfer failed");
        
        // Mark as claimed and record amount
        hasClaimed[msg.sender] = true;
        claimableAmount[msg.sender] = claimAmount;
        claimedAmount[msg.sender] = claimAmount;
        
        // Transfer FOURS tokens to claimer
        _balances[address(this)] -= claimAmount;
        _balances[msg.sender] += claimAmount;
        
        // Update statistics
        totalClaimed += claimAmount;
        totalClaimers++;
        remainingSupply -= claimAmount;
        totalDonated += CLAIM_FEE;
        lastClaimTime = block.timestamp;
        
        // Update tier statistics
        if (tier == 5) totalWhaleClaimers++;
        else if (tier == 4) totalLargeClaimers++;
        else if (tier == 3) totalMediumClaimers++;
        else if (tier == 2) totalSmallClaimers++;
        else if (tier == 1) totalBasicClaimers++;
        
        emit Transfer(address(this), msg.sender, claimAmount);
        emit TokensClaimed(msg.sender, claimAmount, CLAIM_FEE, tier);
        emit DonationSent(msg.sender, CLAIM_FEE);
        
        return true;
    }
    
    // Get claim status for an address
    function getClaimStatus(address user) external view returns (
        bool claimed,
        uint256 eligibleAmount,
        uint256 fourBalance,
        uint256 four402Balance,
        bool canClaim,
        uint256 tier
    ) {
        claimed = hasClaimed[user];
        (eligibleAmount, tier) = calculateClaimableAmount(user);
        fourBalance = IERC20(FOUR_TOKEN_ADDRESS).balanceOf(user);
        four402Balance = IERC20(FOUR402_TOKEN_ADDRESS).balanceOf(user);
        canClaim = !claimed && eligibleAmount > 0 && four402Balance >= CLAIM_FEE;
    }
    
    // Get airdrop statistics
    function getAirdropStats() external view returns (
        uint256 _totalSupply,
        uint256 _totalClaimed,
        uint256 _remainingSupply,
        uint256 _totalClaimers,
        uint256 _estimatedRemainingClaims,
        uint256 _totalDonated,
        uint256 _averageClaim
    ) {
        _totalSupply = MAX_SUPPLY;
        _totalClaimed = totalClaimed;
        _remainingSupply = remainingSupply;
        _totalClaimers = totalClaimers;
        _estimatedRemainingClaims = remainingSupply / (MAX_SUPPLY * CLAIM_PERCENTAGE / CLAIM_DIVISOR);
        _totalDonated = totalDonated;
        _averageClaim = totalClaimers > 0 ? totalClaimed / totalClaimers : 0;
    }
    
    // Get tier distribution statistics
    function getTierStats() external view returns (
        uint256 whales,
        uint256 large,
        uint256 medium,
        uint256 small,
        uint256 basic
    ) {
        whales = totalWhaleClaimers;
        large = totalLargeClaimers;
        medium = totalMediumClaimers;
        small = totalSmallClaimers;
        basic = totalBasicClaimers;
    }
    
    // Get time statistics
    function getTimeStats() external view returns (
        uint256 _launchTime,
        uint256 _lastClaimTime,
        uint256 _runningDays,
        uint256 _claimsPerDay
    ) {
        _launchTime = launchTime;
        _lastClaimTime = lastClaimTime;
        _runningDays = (block.timestamp - launchTime) / 86400;
        _claimsPerDay = _runningDays > 0 ? totalClaimers / _runningDays : totalClaimers;
    }
    
    // Standard ERC20 functions
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
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, currentAllowance - amount);
        
        return true;
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from zero address");
        require(recipient != address(0), "ERC20: transfer to zero address");
        require(_balances[sender] >= amount, "ERC20: transfer amount exceeds balance");
        
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        
        emit Transfer(sender, recipient, amount);
    }
    
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from zero address");
        require(spender != address(0), "ERC20: approve to zero address");
        
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}
