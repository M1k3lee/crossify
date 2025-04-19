// Ethereum Token Factory Contract for Crossify
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title CrossifyToken
 * @dev ERC20 Token created by Crossify Token Factory
 */
contract CrossifyToken is ERC20, Ownable {
    using SafeMath for uint256;
    
    string public metadataURI;
    uint8 private _decimals;
    
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        string memory metadataURI_,
        uint256 initialSupply,
        address owner
    ) ERC20(name, symbol) Ownable(owner) {
        _decimals = decimals_;
        metadataURI = metadataURI_;
        _mint(owner, initialSupply);
    }
    
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    function updateMetadataURI(string memory newMetadataURI) public onlyOwner {
        metadataURI = newMetadataURI;
    }
}

/**
 * @title TokenFactory
 * @dev Factory contract for creating Crossify tokens with cross-chain capabilities
 */
contract TokenFactory is Ownable {
    using SafeMath for uint256;
    
    // Wormhole bridge contract address
    address public wormholeBridge;
    
    // Token data structure
    struct TokenData {
        address tokenAddress;
        string name;
        string symbol;
        uint8 decimals;
        string metadataURI;
        uint256 initialSupply;
        uint256 tokenId;
        bool crossChainEnabled;
        BondingCurve bondingCurve;
        mapping(uint16 => bool) supportedChains;
    }
    
    // Bonding curve structure
    struct BondingCurve {
        bool enabled;
        uint8 curveType; // 0: Linear, 1: Exponential, 2: Bancor
        uint256 basePrice;
        uint256 slope;
        uint16 reserveRatio; // For Bancor formula, represented as parts per 1000
    }
    
    // Cross-chain info structure for events
    struct CrossChainInfo {
        uint16[] supportedChains;
    }
    
    // Token ID counter
    uint256 public tokenCount;
    
    // Mapping from token ID to token data
    mapping(uint256 => TokenData) public tokens;
    
    // Mapping from token address to token ID
    mapping(address => uint256) public tokenIds;
    
    // Events
    event TokenCreated(
        uint256 indexed tokenId,
        address indexed tokenAddress,
        string name,
        string symbol,
        uint8 decimals,
        uint256 initialSupply
    );
    
    event CrossChainEnabled(
        uint256 indexed tokenId,
        address indexed tokenAddress,
        uint16[] supportedChains
    );
    
    event BondingCurveConfigured(
        uint256 indexed tokenId,
        address indexed tokenAddress,
        uint8 curveType,
        uint256 basePrice,
        uint256 slope,
        uint16 reserveRatio
    );
    
    event PriceCalculated(
        uint256 indexed tokenId,
        address indexed tokenAddress,
        uint256 supply,
        uint256 amount,
        uint256 price
    );
    
    event CrossChainMessageSent(
        uint256 indexed tokenId,
        address indexed tokenAddress,
        uint16 targetChain,
        bytes payload
    );
    
    /**
     * @dev Constructor
     * @param wormholeBridge_ Address of the Wormhole bridge contract
     */
    constructor(address wormholeBridge_) Ownable(msg.sender) {
        wormholeBridge = wormholeBridge_;
        tokenCount = 0;
    }
    
    /**
     * @dev Creates a new token
     * @param name Token name
     * @param symbol Token symbol
     * @param decimals Token decimals
     * @param metadataURI Token metadata URI
     * @param initialSupply Initial token supply
     * @return tokenId ID of the created token
     */
    function createToken(
        string memory name,
        string memory symbol,
        uint8 decimals,
        string memory metadataURI,
        uint256 initialSupply
    ) public returns (uint256 tokenId) {
        // Create new token
        CrossifyToken token = new CrossifyToken(
            name,
            symbol,
            decimals,
            metadataURI,
            initialSupply,
            msg.sender
        );
        
        // Store token data
        tokenId = tokenCount;
        TokenData storage tokenData = tokens[tokenId];
        tokenData.tokenAddress = address(token);
        tokenData.name = name;
        tokenData.symbol = symbol;
        tokenData.decimals = decimals;
        tokenData.metadataURI = metadataURI;
        tokenData.initialSupply = initialSupply;
        tokenData.tokenId = tokenId;
        tokenData.crossChainEnabled = false;
        
        // Initialize bonding curve (disabled by default)
        tokenData.bondingCurve.enabled = false;
        tokenData.bondingCurve.curveType = 0;
        tokenData.bondingCurve.basePrice = 0;
        tokenData.bondingCurve.slope = 0;
        tokenData.bondingCurve.reserveRatio = 500; // Default 50%
        
        // Map token address to token ID
        tokenIds[address(token)] = tokenId;
        
        // Increment token count
        tokenCount = tokenCount.add(1);
        
        // Emit event
        emit TokenCreated(
            tokenId,
            address(token),
            name,
            symbol,
            decimals,
            initialSupply
        );
        
        return tokenId;
    }
    
    /**
     * @dev Enables cross-chain functionality for a token
     * @param tokenId ID of the token
     * @param chainIds Chain IDs to enable
     */
    function enableCrossChain(
        uint256 tokenId,
        uint16[] memory chainIds
    ) public {
        // Get token data
        TokenData storage tokenData = tokens[tokenId];
        
        // Check if token exists
        require(tokenData.tokenAddress != address(0), "Token does not exist");
        
        // Check if caller is token owner
        require(
            Ownable(tokenData.tokenAddress).owner() == msg.sender,
            "Caller is not token owner"
        );
        
        // Enable cross-chain functionality
        tokenData.crossChainEnabled = true;
        
        // Add supported chains
        for (uint i = 0; i < chainIds.length; i++) {
            tokenData.supportedChains[chainIds[i]] = true;
        }
        
        // Emit event
        emit CrossChainEnabled(
            tokenId,
            tokenData.tokenAddress,
            chainIds
        );
    }
    
    /**
     * @dev Configures bonding curve for a token
     * @param tokenId ID of the token
     * @param curveType Type of bonding curve (0: Linear, 1: Exponential, 2: Bancor)
     * @param basePrice Base price for the bonding curve
     * @param slope Slope parameter for the bonding curve
     * @param reserveRatio Reserve ratio for Bancor formula (parts per 1000)
     */
    function configureBondingCurve(
        uint256 tokenId,
        uint8 curveType,
        uint256 basePrice,
        uint256 slope,
        uint16 reserveRatio
    ) public {
        // Get token data
        TokenData storage tokenData = tokens[tokenId];
        
        // Check if token exists
        require(tokenData.tokenAddress != address(0), "Token does not exist");
        
        // Check if caller is token owner
        require(
            Ownable(tokenData.tokenAddress).owner() == msg.sender,
            "Caller is not token owner"
        );
        
        // Validate curve parameters
        require(curveType <= 2, "Invalid curve type");
        require(reserveRatio <= 1000, "Invalid reserve ratio"); // Max 100.0%
        
        // Configure bonding curve
        tokenData.bondingCurve.curveType = curveType;
        tokenData.bondingCurve.basePrice = basePrice;
        tokenData.bondingCurve.slope = slope;
        tokenData.bondingCurve.reserveRatio = reserveRatio;
        tokenData.bondingCurve.enabled = true;
        
        // Emit event
        emit BondingCurveConfigured(
            tokenId,
            tokenData.tokenAddress,
            curveType,
            basePrice,
            slope,
            reserveRatio
        );
    }
    
    /**
     * @dev Calculates price using bonding curve
     * @param tokenId ID of the token
     * @param supply Current token supply
     * @param amount Amount to buy/sell
     * @return price Calculated price
     */
    function calculatePrice(
        uint256 tokenId,
        uint256 supply,
        uint256 amount
    ) public returns (uint256 price) {
        // Get token data
        TokenData storage tokenData = tokens[tokenId];
        
        // Check if token exists
        require(tokenData.tokenAddress != address(0), "Token does not exist");
        
        // Check if bonding curve is enabled
        require(tokenData.bondingCurve.enabled, "Bonding curve not enabled");
        
        // Calculate price based on curve type
        if (tokenData.bondingCurve.curveType == 0) {
            // Linear curve: P = base_price + slope * supply
            price = calculateLinearPrice(
                supply,
                amount,
                tokenData.bondingCurve.basePrice,
                tokenData.bondingCurve.slope
            );
        } else if (tokenData.bondingCurve.curveType == 1) {
            // Exponential curve: P = base_price * (1 + slope)^supply
            price = calculateExponentialPrice(
                supply,
                amount,
                tokenData.bondingCurve.basePrice,
                tokenData.bondingCurve.slope
            );
        } else if (tokenData.bondingCurve.curveType == 2) {
            // Bancor curve: P = base_price * (supply / initial_supply)^((1 / reserve_ratio) - 1)
            price = calculateBancorPrice(
                supply,
                amount,
                tokenData.bondingCurve.basePrice,
                tokenData.bondingCurve.reserveRatio
            );
        } else {
            revert("Invalid curve type");
        }
        
        // Emit event
        emit PriceCalculated(
            tokenId,
            tokenData.tokenAddress,
            supply,
            amount,
            price
        );
        
        return price;
    }
    
    /**
     * @dev Sends cross-chain message
     * @param tokenId ID of the token
     * @param targetChain Target chain ID
     * @param payload Message payload
     */
    function sendCrossChainMessage(
        uint256 tokenId,
        uint16 targetChain,
        bytes memory payload
    ) public {
        // Get token data
        TokenData storage tokenData = tokens[tokenId];
        
        // Check if token exists
        require(tokenData.tokenAddress != address(0), "Token does not exist");
        
        // Check if caller is token owner
        require(
            Ownable(tokenData.tokenAddress).owner() == msg.sender,
            "Caller is not token owner"
        );
        
        // Check if cross-chain is enabled
        require(tokenData.crossChainEnabled, "Cross-chain not enabled");
        
        // Check if target chain is supported
        require(tokenData.supportedChains[targetChain], "Unsupported chain");
        
        // In a real implementation, this would call the Wormhole bridge to send the message
        // For now, we just emit an event
        emit CrossChainMessageSent(
            tokenId,
            tokenData.tokenAddress,
            targetChain,
            payload
        );
    }
    
    /**
     * @dev Updates Wormhole bridge address
     * @param newWormholeBridge New Wormhole bridge address
     */
    function updateWormholeBridge(address newWormholeBridge) public onlyOwner {
        wormholeBridge = newWormholeBridge;
    }
    
    // Helper functions for price calculation
    
    /**
     * @dev Calculates price using linear bonding curve
     * @param supply Current token supply
     * @param amount Amount to buy/sell
     * @param basePrice Base price for the bonding curve
     * @param slope Slope parameter for the bonding curve
     * @return price Calculated price
     */
    function calculateLinearPrice(
        uint256 supply,
        uint256 amount,
        uint256 basePrice,
        uint256 slope
    ) internal pure returns (uint256) {
        // P = base_price + slope * supply
        uint256 currentPrice = basePrice.add(slope.mul(supply));
        return currentPrice.mul(amount);
    }
    
    /**
     * @dev Calculates price using exponential bonding curve
     * @param supply Current token supply
     * @param amount Amount to buy/sell
     * @param basePrice Base price for the bonding curve
     * @param slope Slope parameter for the bonding curve
     * @return price Calculated price
     */
    function calculateExponentialPrice(
        uint256 supply,
        uint256 amount,
        uint256 basePrice,
        uint256 slope
    ) internal pure returns (uint256) {
        // P = base_price * (1 + slope)^supply
        // For simplicity, we approximate this with a simpler formula
        uint256 exponent = slope.mul(supply).div(10000); // Scaled slope
        uint256 currentPrice = basePrice.add(basePrice.mul(exponent).div(100));
        return currentPrice.mul(amount);
    }
    
    /**
     * @dev Calculates price using Bancor bonding curve
     * @param supply Current token supply
     * @param amount Amount to buy/sell
     * @param basePrice Base price for the bonding curve
     * @param reserveRatio Reserve ratio for Bancor formula (parts per 1000)
     * @return price Calculated price
     */
    function calculateBancorPrice(
        uint256 supply,
        uint256 amount,
        uint256 basePrice,
        uint16 reserveRatio
    ) internal pure returns (uint256) {
        // Bancor formula: P = base_price * (supply / initial_supply)^((1 / reserve_ratio) - 1)
        // For simplicity, we approximate this with a simpler formula
        uint256 ratioFactor = uint256(1000).sub(reserveRatio).div(1000);
        uint256 supplyFactor = supply > 1000 ? supply.div(1000) : 1;
        
        // Simple power approximation for demo purposes
        uint256 power = 1;
        for (uint i = 0; i < ratioFactor; i++) {
            power = power.mul(supplyFactor);
        }
        
        uint256 currentPrice = basePrice.mul(power);
        return currentPrice.mul(amount);
    }
}
