// Cross-chain integration module for Crossify
// This file contains the integration between Solana and Ethereum implementations

use anchor_lang::prelude::*;
use std::mem::size_of;

// Import Wormhole module
mod wormhole;
use wormhole::*;

#[derive(Accounts)]
pub struct ReceiveWormholeMessage<'info> {
    #[account(mut)]
    pub token_data: Account<'info, crate::TokenData>,
    
    #[account(mut)]
    pub authority: Signer<'info>,
    
    pub system_program: Program<'info, System>,
}

impl<'info> ReceiveWormholeMessage<'info> {
    pub fn process_message(
        &mut self,
        source_chain: u16,
        source_address: Vec<u8>,
        payload: Vec<u8>
    ) -> Result<()> {
        // Verify the source is trusted
        // In a real implementation, this would check against a list of trusted emitters
        
        // Parse message type
        require!(!payload.is_empty(), crate::TokenFactoryError::InvalidMessagePayload);
        let message_type = payload[0];
        
        // Process message based on type
        match message_type {
            MSG_TYPE_TOKEN_CREATION => self.process_token_creation(source_chain, payload[1..].to_vec()),
            MSG_TYPE_PRICE_UPDATE => self.process_price_update(source_chain, payload[1..].to_vec()),
            MSG_TYPE_LIQUIDITY_UPDATE => self.process_liquidity_update(source_chain, payload[1..].to_vec()),
            _ => Err(crate::TokenFactoryError::UnknownMessageType.into())
        }
    }
    
    fn process_token_creation(&mut self, source_chain: u16, payload: Vec<u8>) -> Result<()> {
        // Parse token creation payload
        let token_creation_payload = parse_token_creation_message(&payload)?;
        
        // In a real implementation, this would create a wrapped token
        // For now, we just emit an event
        emit!(TokenCreatedFromRemoteEvent {
            token_id: token_creation_payload.token_id,
            name: token_creation_payload.name,
            symbol: token_creation_payload.symbol,
            source_chain,
        });
        
        Ok(())
    }
    
    fn process_price_update(&mut self, source_chain: u16, payload: Vec<u8>) -> Result<()> {
        // Parse price update payload
        let price_update_payload = parse_price_update_message(&payload)?;
        
        // In a real implementation, this would update the token price
        // For now, we just emit an event
        emit!(PriceUpdatedFromRemoteEvent {
            token_id: price_update_payload.token_id,
            current_price: price_update_payload.current_price,
            current_supply: price_update_payload.current_supply,
            source_chain,
        });
        
        Ok(())
    }
    
    fn process_liquidity_update(&mut self, source_chain: u16, payload: Vec<u8>) -> Result<()> {
        // Parse liquidity update payload
        let liquidity_update_payload = parse_liquidity_update_message(&payload)?;
        
        // In a real implementation, this would update the token liquidity
        // For now, we just emit an event
        emit!(LiquidityUpdatedFromRemoteEvent {
            token_id: liquidity_update_payload.token_id,
            current_liquidity: liquidity_update_payload.current_liquidity,
            source_chain,
        });
        
        Ok(())
    }
}

#[event]
pub struct TokenCreatedFromRemoteEvent {
    pub token_id: u64,
    pub name: String,
    pub symbol: String,
    pub source_chain: u16,
}

#[event]
pub struct PriceUpdatedFromRemoteEvent {
    pub token_id: u64,
    pub current_price: u64,
    pub current_supply: u64,
    pub source_chain: u16,
}

#[event]
pub struct LiquidityUpdatedFromRemoteEvent {
    pub token_id: u64,
    pub current_liquidity: u64,
    pub source_chain: u16,
}

// Add these error types to the main TokenFactoryError enum
// #[error_code]
// pub enum TokenFactoryError {
//     #[msg("Invalid message payload")]
//     InvalidMessagePayload,
//     
//     #[msg("Unknown message type")]
//     UnknownMessageType,
// }
