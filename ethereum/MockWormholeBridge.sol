// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockWormholeBridge
 * @dev Mock implementation of Wormhole Bridge for testnet deployment
 */
contract MockWormholeBridge {
    // Events
    event LogMessagePublished(
        address indexed sender,
        uint16 targetChain,
        bytes targetAddress,
        bytes payload,
        uint256 sequence
    );
    
    // Message sequence counter
    uint256 private sequence;
    
    constructor() {
        sequence = 0;
    }
    
    /**
     * @dev Publishes a message to the Wormhole network
     * @param targetChain Target chain ID
     * @param targetAddress Target address on the target chain
     * @param payload Message payload
     * @return sequence Sequence number of the published message
     */
    function publishMessage(
        uint16 targetChain,
        bytes memory targetAddress,
        bytes memory payload
    ) external returns (uint256) {
        // Increment sequence
        sequence += 1;
        
        // Emit event
        emit LogMessagePublished(
            msg.sender,
            targetChain,
            targetAddress,
            payload,
            sequence
        );
        
        return sequence;
    }
}
