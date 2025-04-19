// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./TokenFactory.sol";
import "./CrossifyBridge.sol";
import "./MockWormholeBridge.sol";

/**
 * @title CrossifyTest
 * @dev Test contract for Crossify platform on testnet
 */
contract CrossifyTest {
    // References to deployed contracts
    TokenFactory public tokenFactory;
    CrossifyBridge public crossifyBridge;
    MockWormholeBridge public mockWormholeBridge;
    
    // Test token data
    struct TestToken {
        uint256 tokenId;
        address tokenAddress;
        string name;
        string symbol;
    }
    
    // Array of test tokens
    TestToken[] public testTokens;
    
    // Events
    event TestTokenCreated(
        uint256 indexed tokenId,
        address indexed tokenAddress,
        string name,
        string symbol
    );
    
    event CrossChainMessageSent(
        uint256 indexed tokenId,
        uint16 targetChain
    );
    
    /**
     * @dev Constructor
     * @param tokenFactory_ Address of the TokenFactory contract
     * @param crossifyBridge_ Address of the CrossifyBridge contract
     * @param mockWormholeBridge_ Address of the MockWormholeBridge contract
     */
    constructor(
        address tokenFactory_,
        address crossifyBridge_,
        address mockWormholeBridge_
    ) {
        tokenFactory = TokenFactory(tokenFactory_);
        crossifyBridge = CrossifyBridge(crossifyBridge_);
        mockWormholeBridge = MockWormholeBridge(mockWormholeBridge_);
    }
    
    /**
     * @dev Creates a test token
     * @param name Token name
     * @param symbol Token symbol
     * @param decimals Token decimals
     * @param metadataURI Token metadata URI
     * @param initialSupply Initial token supply
     * @return tokenId ID of the created token
     */
    function createTestToken(
        string memory name,
        string memory symbol,
        uint8 decimals,
        string memory metadataURI,
        uint256 initialSupply
    ) public returns (uint256 tokenId) {
        // Create token using TokenFactory
        tokenId = tokenFactory.createToken(
            name,
            symbol,
            decimals,
            metadataURI,
            initialSupply
        );
        
        // Get token address
        (address tokenAddress, , , , , , , , , , , , , ) = tokenFactory.tokens(tokenId);
        
        // Store test token data
        testTokens.push(TestToken({
            tokenId: tokenId,
            tokenAddress: tokenAddress,
            name: name,
            symbol: symbol
        }));
        
        // Emit event
        emit TestTokenCreated(
            tokenId,
            tokenAddress,
            name,
            symbol
        );
        
        return tokenId;
    }
    
    /**
     * @dev Enables cross-chain functionality for a test token
     * @param tokenId Token ID
     * @param chainIds Chain IDs to enable
     */
    function enableCrossChain(
        uint256 tokenId,
        uint16[] memory chainIds
    ) public {
        // Enable cross-chain using TokenFactory
        tokenFactory.enableCrossChain(tokenId, chainIds);
    }
    
    /**
     * @dev Configures bonding curve for a test token
     * @param tokenId Token ID
     * @param curveType Type of bonding curve
     * @param basePrice Base price for the bonding curve
     * @param slope Slope parameter for the bonding curve
     * @param reserveRatio Reserve ratio for Bancor formula
     */
    function configureBondingCurve(
        uint256 tokenId,
        uint8 curveType,
        uint256 basePrice,
        uint256 slope,
        uint16 reserveRatio
    ) public {
        // Configure bonding curve using TokenFactory
        tokenFactory.configureBondingCurve(
            tokenId,
            curveType,
            basePrice,
            slope,
            reserveRatio
        );
    }
    
    /**
     * @dev Sends a cross-chain message for a test token
     * @param tokenId Token ID
     * @param targetChain Target chain ID
     */
    function sendCrossChainMessage(
        uint256 tokenId,
        uint16 targetChain
    ) public {
        // Create a simple test payload
        bytes memory payload = abi.encodePacked("Test message from token ", tokenId);
        
        // Send message using TokenFactory
        tokenFactory.sendCrossChainMessage(tokenId, targetChain, payload);
        
        // Emit event
        emit CrossChainMessageSent(tokenId, targetChain);
    }
    
    /**
     * @dev Gets the number of test tokens
     * @return count Number of test tokens
     */
    function getTestTokenCount() public view returns (uint256 count) {
        return testTokens.length;
    }
}
