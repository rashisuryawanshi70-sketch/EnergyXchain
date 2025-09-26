// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title EnergyXChain - Decentralized Energy Trading Platform
 * @dev Smart contract for peer-to-peer energy trading and management
 * @author EnergyXChain Development Team
 */
contract Project {
    // State variables
    address public owner;
    uint256 public totalEnergyTraded;
    uint256 public transactionCounter;
    
    // Energy provider structure
    struct EnergyProvider {
        address providerAddress;
        string name;
        uint256 energyProduced; // in kWh
        uint256 pricePerKWh; // in wei
        bool isActive;
        uint256 reputation; // 0-100 scale
    }
    
    // Energy transaction structure
    struct EnergyTransaction {
        uint256 transactionId;
        address buyer;
        address seller;
        uint256 energyAmount; // in kWh
        uint256 totalPrice; // in wei
        uint256 timestamp;
        bool isCompleted;
    }
    
    // Mappings
    mapping(address => EnergyProvider) public energyProviders;
    mapping(uint256 => EnergyTransaction) public energyTransactions;
    mapping(address => uint256) public userEnergyBalance;
    mapping(address => bool) public isRegisteredProvider;
    
    // Events
    event ProviderRegistered(address indexed provider, string name);
    event EnergyListed(address indexed provider, uint256 amount, uint256 pricePerKWh);
    event EnergyTraded(
        uint256 indexed transactionId,
        address indexed buyer,
        address indexed seller,
        uint256 amount,
        uint256 totalPrice
    );
    event ReputationUpdated(address indexed provider, uint256 newReputation);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can call this function");
        _;
    }
    
    modifier onlyRegisteredProvider() {
        require(isRegisteredProvider[msg.sender], "Only registered providers can call this function");
        _;
    }
    
    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "Amount must be greater than zero");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        totalEnergyTraded = 0;
        transactionCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Register as an energy provider
     * @param _name Provider name
     * @param _initialEnergyProduced Initial energy production capacity
     * @param _pricePerKWh Price per kWh in wei
     */
    function registerEnergyProvider(
        string memory _name,
        uint256 _initialEnergyProduced,
        uint256 _pricePerKWh
    ) external validAmount(_initialEnergyProduced) validAmount(_pricePerKWh) {
        require(!isRegisteredProvider[msg.sender], "Provider already registered");
        require(bytes(_name).length > 0, "Provider name cannot be empty");
        
        energyProviders[msg.sender] = EnergyProvider({
            providerAddress: msg.sender,
            name: _name,
            energyProduced: _initialEnergyProduced,
            pricePerKWh: _pricePerKWh,
            isActive: true,
            reputation: 50 // Start with neutral reputation
        });
        
        isRegisteredProvider[msg.sender] = true;
        
        emit ProviderRegistered(msg.sender, _name);
        emit EnergyListed(msg.sender, _initialEnergyProduced, _pricePerKWh);
    }
    
    /**
     * @dev Core Function 2: Purchase energy from a provider
     * @param _providerAddress Address of the energy provider
     * @param _energyAmount Amount of energy to purchase in kWh
     */
    function purchaseEnergy(
        address _providerAddress,
        uint256 _energyAmount
    ) external payable validAmount(_energyAmount) {
        require(isRegisteredProvider[_providerAddress], "Provider not registered");
        require(_providerAddress != msg.sender, "Cannot purchase from yourself");
        
        EnergyProvider storage provider = energyProviders[_providerAddress];
        require(provider.isActive, "Provider is not active");
        require(provider.energyProduced >= _energyAmount, "Insufficient energy available");
        
        uint256 totalPrice = _energyAmount * provider.pricePerKWh;
        require(msg.value >= totalPrice, "Insufficient payment");
        
        // Update provider's available energy
        provider.energyProduced -= _energyAmount;
        
        // Update buyer's energy balance
        userEnergyBalance[msg.sender] += _energyAmount;
        
        // Create transaction record
        transactionCounter++;
        energyTransactions[transactionCounter] = EnergyTransaction({
            transactionId: transactionCounter,
            buyer: msg.sender,
            seller: _providerAddress,
            energyAmount: _energyAmount,
            totalPrice: totalPrice,
            timestamp: block.timestamp,
            isCompleted: true
        });
        
        // Update global stats
        totalEnergyTraded += _energyAmount;
        
        // Transfer payment to provider
        payable(_providerAddress).transfer(totalPrice);
        
        // Refund excess payment if any
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
        
        emit EnergyTraded(transactionCounter, msg.sender, _providerAddress, _energyAmount, totalPrice);
    }
    
    /**
     * @dev Core Function 3: Update provider reputation and energy availability
     * @param _providerAddress Provider address to update
     * @param _newReputation New reputation score (0-100)
     * @param _additionalEnergy Additional energy to add to inventory
     */
    function updateProviderStatus(
        address _providerAddress,
        uint256 _newReputation,
        uint256 _additionalEnergy
    ) external onlyOwner {
        require(isRegisteredProvider[_providerAddress], "Provider not registered");
        require(_newReputation <= 100, "Reputation cannot exceed 100");
        
        EnergyProvider storage provider = energyProviders[_providerAddress];
        provider.reputation = _newReputation;
        
        if (_additionalEnergy > 0) {
            provider.energyProduced += _additionalEnergy;
        }
        
        emit ReputationUpdated(_providerAddress, _newReputation);
        
        if (_additionalEnergy > 0) {
            emit EnergyListed(_providerAddress, _additionalEnergy, provider.pricePerKWh);
        }
    }
    
    // View functions
    function getProviderDetails(address _providerAddress) 
        external 
        view 
        returns (
            string memory name,
            uint256 energyProduced,
            uint256 pricePerKWh,
            bool isActive,
            uint256 reputation
        ) 
    {
        EnergyProvider memory provider = energyProviders[_providerAddress];
        return (
            provider.name,
            provider.energyProduced,
            provider.pricePerKWh,
            provider.isActive,
            provider.reputation
        );
    }
    
    function getTransactionDetails(uint256 _transactionId)
        external
        view
        returns (
            address buyer,
            address seller,
            uint256 energyAmount,
            uint256 totalPrice,
            uint256 timestamp,
            bool isCompleted
        )
    {
        EnergyTransaction memory transaction = energyTransactions[_transactionId];
        return (
            transaction.buyer,
            transaction.seller,
            transaction.energyAmount,
            transaction.totalPrice,
            transaction.timestamp,
            transaction.isCompleted
        );
    }
    
    function getUserEnergyBalance(address _user) external view returns (uint256) {
        return userEnergyBalance[_user];
    }
    
    function getContractStats() 
        external 
        view 
        returns (
            uint256 totalEnergy,
            uint256 totalTransactions,
            address contractOwner
        ) 
    {
        return (totalEnergyTraded, transactionCounter, owner);
    }
    
    // Emergency functions
    function toggleProviderStatus(address _providerAddress) external onlyOwner {
        require(isRegisteredProvider[_providerAddress], "Provider not registered");
        energyProviders[_providerAddress].isActive = !energyProviders[_providerAddress].isActive;
    }
    
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
