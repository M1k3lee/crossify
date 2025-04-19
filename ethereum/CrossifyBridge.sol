// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./TokenFactory.sol";
import "./WormholeIntegration.sol";

/**
 * @title CrossifyBridge
 * @dev Bridge contract for cross-chain token operations in Crossify
 */
contract CrossifyBridge is WormholeIntegration {
    // Reference to the TokenFactory contract
    TokenFactory public tokenFactory;
    
    // Mapping from source chain to emitter address
    mapping(uint16 => bytes) public trustedEmitters;
    
    // Events
    event TokenCreatedFromRemote(
        uint256 indexed tokenId,
        address indexed tokenAddress,
        uint16 sourceChain
    );
    
    event PriceUpdatedFromRemote(
        uint256 indexed tokenId,
        address indexed tokenAddress,
        uint256 newPrice,
        uint16 sourceChain
    );
    
    event LiquidityUpdatedFromRemote(
        uint256 indexed tokenId,
        address indexed tokenAddress,
        uint256 newLiquidity,
        uint16 sourceChain
    );
    
    /**
     * @dev Constructor
     * @param tokenFactory_ Address of the TokenFactory contract
     * @param wormholeBridge_ Address of the Wormhole Core Bridge
     * @param wormholeTokenBridge_ Address of the Wormhole Token Bridge
     */
    constructor(
        address tokenFactory_,
        address wormholeBridge_,
        address wormholeTokenBridge_
    ) WormholeIntegration(wormholeBridge_, wormholeTokenBridge_) {
        tokenFactory = TokenFactory(tokenFactory_);
    }
    
    /**
     * @dev Registers a trusted emitter for a source chain
     * @param sourceChain Source chain ID
     * @param emitterAddress Emitter address on the source chain
     */
    function registerEmitter(
        uint16 sourceChain,
        bytes memory emitterAddress
    ) external {
        // Only the owner of the TokenFactory can register emitters
        require(
            msg.sender == tokenFactory.owner(),
            "Caller is not TokenFactory owner"
        );
        
        trustedEmitters[sourceChain] = emitterAddress;
    }
    
    /**
     * @dev Processes a received Wormhole message
     * @param sourceChain Source chain ID
     * @param sourceAddress Source address on the source chain
     * @param payload Message payload
     */
    function processMessage(
        uint16 sourceChain,
        bytes memory sourceAddress,
        bytes memory payload
    ) external {
        // Verify the source is trusted
        require(
            keccak256(trustedEmitters[sourceChain]) == keccak256(sourceAddress),
            "Untrusted source"
        );
        
        // Parse message type
        require(payload.length > 0, "Empty payload");
        uint8 messageType = uint8(payload[0]);
        
        // Process message based on type
        if (messageType == MSG_TYPE_TOKEN_CREATION) {
            processTokenCreation(sourceChain, payload[1:]);
        } else if (messageType == MSG_TYPE_PRICE_UPDATE) {
            processPriceUpdate(sourceChain, payload[1:]);
        } else if (messageType == MSG_TYPE_LIQUIDITY_UPDATE) {
            processLiquidityUpdate(sourceChain, payload[1:]);
        } else {
            revert("Unknown message type");
        }
        
        emit MessageReceived(sourceChain, sourceAddress, payload);
    }
    
    /**
     * @dev Processes a token creation message
     * @param sourceChain Source chain ID
     * @param payload Message payload
     */
    function processTokenCreation(
        uint16 sourceChain,
        bytes memory payload
    ) internal {
        // In a real implementation, this would parse the payload and create a token
        // For now, we just emit an event
        emit TokenCreatedFromRemote(0, address(0), sourceChain);
    }
    
    /**
     * @dev Processes a price update message
     * @param sourceChain Source chain ID
     * @param payload Message payload
     */
    function processPriceUpdate(
        uint16 sourceChain,
        bytes memory payload
    ) internal {
        // In a real implementation, this would parse the payload and update the price
        // For now, we just emit an event
        emit PriceUpdatedFromRemote(0, address(0), 0, sourceChain);
    }
    
    /**
     * @dev Processes a liquidity update message
     * @param sourceChain Source chain ID
     * @param payload Message payload
     */
    function processLiquidityUpdate(
        uint16 sourceChain,
        bytes memory payload
    ) internal {
        // In a real implementation, this would parse the payload and update the liquidity
        // For now, we just emit an event
        emit LiquidityUpdatedFromRemote(0, address(0), 0, sourceChain);
    }
    
    /**
     * @dev Sends a token creation message to a target chain
     * @param tokenId Token ID
     * @param targetChain Target chain ID
     */
    function sendTokenCreation(
        uint256 tokenId,
        uint16 targetChain
    ) external {
        // Only the TokenFactory can send messages
        require(
            msg.sender == address(tokenFactory),
            "Caller is not TokenFactory"
        );
        
        // Get token data
        (
            address tokenAddress,
            string memory name,
            string memory symbol,
            uint8 decimals,
            string memory metadataURI,
            uint256 initialSupply,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            
        ) = tokenFactory.tokens(tokenId);
        
        // Get bonding curve data
        // In a real implementation, this would get the actual bonding curve data
        uint8 curveType = 0;
        uint256 basePrice = 0;
        uint256 slope = 0;
        uint16 reserveRatio = 500;
        
        // Serialize message
        bytes memory payload = serializeTokenCreationMessage(
            tokenId,
            name,
            symbol,
            decimals,
            metadataURI,
            initialSupply,
            curveType,
            basePrice,
            slope,
            reserveRatio
        );
        
        // Get target address (the bridge contract on the target chain)
        // In a real implementation, this would be the actual address
        bytes memory targetAddress = new bytes(32);
        
        // Send message
        sendMessage(targetChain, targetAddress, payload);
    }
    
    /**
     * @dev Sends a price update message to a target chain
     * @param tokenId Token ID
     * @param currentPrice Current token price
     * @param currentSupply Current token supply
     * @param targetChain Target chain ID
     */
    function sendPriceUpdate(
        uint256 tokenId,
        uint256 currentPrice,
        uint256 currentSupply,
        uint16 targetChain
    ) external {
        // Only the TokenFactory can send messages
        require(
            msg.sender == address(tokenFactory),
            "Caller is not TokenFactory"
        );
        
        // Serialize message
        bytes memory payload = serializePriceUpdateMessage(
            tokenId,
            currentPrice,
            currentSupply
        );
        
        // Get target address (the bridge contract on the target chain)
        // In a real implementation, this would be the actual address
        bytes memory targetAddress = new bytes(32);
        
        // Send message
        sendMessage(targetChain, targetAddress, payload);
    }
    
    /**
     * @dev Sends a liquidity update message to a target chain
     * @param tokenId Token ID
     * @param liquidityAdded Amount of liquidity added
     * @param liquidityRemoved Amount of liquidity removed
     * @param currentLiquidity Current liquidity amount
     * @param targetChain Target chain ID
     */
    function sendLiquidityUpdate(
        uint256 tokenId,
        uint256 liquidityAdded,
        uint256 liquidityRemoved,
        uint256 currentLiquidity,
        uint16 targetChain
    ) external {
        // Only the TokenFactory can send messages
        require(
            msg.sender == address(tokenFactory),
            "Caller is not TokenFactory"
        );
        
        // Serialize message
        bytes memory payload = serializeLiquidityUpdateMessage(
            tokenId,
            liquidityAdded,
            liquidityRemoved,
            currentLiquidity
        );
        
        // Get target address (the bridge contract on the target chain)
        // In a real implementation, this would be the actual address
        bytes memory targetAddress = new bytes(32);
        
        // Send message
        sendMessage(targetChain, targetAddress, payload);
    }
    
    /**
     * @dev Updates the TokenFactory address
     * @param newTokenFactory New TokenFactory address
     */
    function updateTokenFactory(address newTokenFactory) external {
        // Only the current TokenFactory owner can update
        require(
            msg.sender == tokenFactory.owner(),
            "Caller is not TokenFactory owner"
        );
        
        tokenFactory = TokenFactory(newTokenFactory);
    }
    
    /**
     * @dev Updates Wormhole bridge addresses
     * @param newWormholeBridge New Wormhole Core Bridge address
     * @param newWormholeTokenBridge New Wormhole Token Bridge address
     */
    function updateWormholeBridges(
        address newWormholeBridge,
        address newWormholeTokenBridge
    ) external {
        // Only the TokenFactory owner can update
        require(
            msg.sender == tokenFactory.owner(),
            "Caller is not TokenFactory owner"
        );
        
        updateWormholeBridges(newWormholeBridge, newWormholeTokenBridge);
    }
}
