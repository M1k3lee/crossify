use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount};
use std::mem::size_of;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS");

#[program]
pub mod token_factory {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        let token_factory = &mut ctx.accounts.token_factory;
        token_factory.authority = ctx.accounts.authority.key();
        token_factory.token_count = 0;
        Ok(())
    }

    pub fn create_token(
        ctx: Context<CreateToken>,
        name: String,
        symbol: String,
        decimals: u8,
        metadata_uri: String,
        initial_supply: u64,
    ) -> Result<()> {
        let token_factory = &mut ctx.accounts.token_factory;
        let token_data = &mut ctx.accounts.token_data;
        let mint = &ctx.accounts.mint;
        let token_account = &ctx.accounts.token_account;
        let authority = &ctx.accounts.authority;
        
        // Initialize token data
        token_data.mint = mint.key();
        token_data.name = name;
        token_data.symbol = symbol;
        token_data.decimals = decimals;
        token_data.metadata_uri = metadata_uri;
        token_data.authority = authority.key();
        token_data.initial_supply = initial_supply;
        token_data.cross_chain_enabled = false;
        token_data.cross_chain_info = CrossChainInfo::default();
        token_data.token_id = token_factory.token_count;
        token_data.bonding_curve = BondingCurve::default();
        
        // Mint initial supply to token account
        token::mint_to(
            CpiContext::new(
                ctx.accounts.token_program.to_account_info(),
                token::MintTo {
                    mint: ctx.accounts.mint.to_account_info(),
                    to: ctx.accounts.token_account.to_account_info(),
                    authority: ctx.accounts.authority.to_account_info(),
                },
            ),
            initial_supply,
        )?;
        
        // Increment token count
        token_factory.token_count += 1;
        
        emit!(TokenCreatedEvent {
            token_id: token_data.token_id,
            mint: token_data.mint,
            name: token_data.name.clone(),
            symbol: token_data.symbol.clone(),
            decimals: token_data.decimals,
            initial_supply: token_data.initial_supply,
        });
        
        Ok(())
    }

    pub fn enable_cross_chain(
        ctx: Context<EnableCrossChain>,
        wormhole_emitter: Pubkey,
        chain_ids: Vec<u16>,
    ) -> Result<()> {
        let token_data = &mut ctx.accounts.token_data;
        let authority = &ctx.accounts.authority;
        
        // Verify authority
        require!(token_data.authority == authority.key(), TokenFactoryError::InvalidAuthority);
        
        // Enable cross-chain functionality
        token_data.cross_chain_enabled = true;
        token_data.cross_chain_info.wormhole_emitter = wormhole_emitter;
        token_data.cross_chain_info.supported_chains = chain_ids;
        
        emit!(CrossChainEnabledEvent {
            token_id: token_data.token_id,
            mint: token_data.mint,
            wormhole_emitter,
            supported_chains: chain_ids.clone(),
        });
        
        Ok(())
    }

    pub fn configure_bonding_curve(
        ctx: Context<ConfigureBondingCurve>,
        curve_type: u8,
        base_price: u64,
        slope: u64,
        reserve_ratio: u16,
    ) -> Result<()> {
        let token_data = &mut ctx.accounts.token_data;
        let authority = &ctx.accounts.authority;
        
        // Verify authority
        require!(token_data.authority == authority.key(), TokenFactoryError::InvalidAuthority);
        
        // Validate curve parameters
        require!(curve_type <= 2, TokenFactoryError::InvalidCurveType);
        require!(reserve_ratio <= 1000, TokenFactoryError::InvalidReserveRatio); // Max 100.0%
        
        // Configure bonding curve
        token_data.bonding_curve.curve_type = curve_type;
        token_data.bonding_curve.base_price = base_price;
        token_data.bonding_curve.slope = slope;
        token_data.bonding_curve.reserve_ratio = reserve_ratio;
        token_data.bonding_curve.enabled = true;
        
        emit!(BondingCurveConfiguredEvent {
            token_id: token_data.token_id,
            mint: token_data.mint,
            curve_type,
            base_price,
            slope,
            reserve_ratio,
        });
        
        Ok(())
    }

    pub fn calculate_price(
        ctx: Context<CalculatePrice>,
        supply: u64,
        amount: u64,
    ) -> Result<u64> {
        let token_data = &ctx.accounts.token_data;
        
        // Verify bonding curve is enabled
        require!(token_data.bonding_curve.enabled, TokenFactoryError::BondingCurveNotEnabled);
        
        let price = match token_data.bonding_curve.curve_type {
            0 => calculate_linear_price(
                supply,
                amount,
                token_data.bonding_curve.base_price,
                token_data.bonding_curve.slope,
            ),
            1 => calculate_exponential_price(
                supply,
                amount,
                token_data.bonding_curve.base_price,
                token_data.bonding_curve.slope,
            ),
            2 => calculate_bancor_price(
                supply,
                amount,
                token_data.bonding_curve.base_price,
                token_data.bonding_curve.reserve_ratio,
            ),
            _ => return Err(TokenFactoryError::InvalidCurveType.into()),
        };
        
        emit!(PriceCalculatedEvent {
            token_id: token_data.token_id,
            mint: token_data.mint,
            supply,
            amount,
            price,
        });
        
        Ok(price)
    }

    pub fn send_cross_chain_message(
        ctx: Context<SendCrossChainMessage>,
        target_chain: u16,
        payload: Vec<u8>,
    ) -> Result<()> {
        let token_data = &ctx.accounts.token_data;
        let authority = &ctx.accounts.authority;
        
        // Verify authority
        require!(token_data.authority == authority.key(), TokenFactoryError::InvalidAuthority);
        
        // Verify cross-chain is enabled
        require!(token_data.cross_chain_enabled, TokenFactoryError::CrossChainNotEnabled);
        
        // Verify target chain is supported
        require!(
            token_data.cross_chain_info.supported_chains.contains(&target_chain),
            TokenFactoryError::UnsupportedChain
        );
        
        // In a real implementation, this would call the Wormhole bridge to send the message
        // For now, we just emit an event
        emit!(CrossChainMessageSentEvent {
            token_id: token_data.token_id,
            mint: token_data.mint,
            target_chain,
            payload: payload.clone(),
        });
        
        Ok(())
    }
}

// Helper functions for price calculation
fn calculate_linear_price(supply: u64, amount: u64, base_price: u64, slope: u64) -> u64 {
    // P = base_price + slope * supply
    let current_price = base_price.saturating_add(slope.saturating_mul(supply));
    current_price.saturating_mul(amount)
}

fn calculate_exponential_price(supply: u64, amount: u64, base_price: u64, slope: u64) -> u64 {
    // P = base_price * (1 + slope)^supply
    // For simplicity, we approximate this with a simpler formula
    let exponent = slope.saturating_mul(supply) / 10000; // Scaled slope
    let current_price = base_price.saturating_add(base_price.saturating_mul(exponent) / 100);
    current_price.saturating_mul(amount)
}

fn calculate_bancor_price(supply: u64, amount: u64, base_price: u64, reserve_ratio: u16) -> u64 {
    // Bancor formula: P = base_price * (supply / initial_supply)^((1 / reserve_ratio) - 1)
    // For simplicity, we approximate this with a simpler formula
    let ratio_factor = 1000_u64.saturating_sub(reserve_ratio as u64) / 1000;
    let supply_factor = if supply > 1000 { supply / 1000 } else { 1 };
    let current_price = base_price.saturating_mul(supply_factor.saturating_pow(ratio_factor as u32));
    current_price.saturating_mul(amount)
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(
        init,
        payer = authority,
        space = 8 + size_of::<TokenFactory>()
    )]
    pub token_factory: Account<'info, TokenFactory>,
    
    #[account(mut)]
    pub authority: Signer<'info>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct CreateToken<'info> {
    #[account(mut)]
    pub token_factory: Account<'info, TokenFactory>,
    
    #[account(
        init,
        payer = authority,
        space = 8 + size_of::<TokenData>() + 256, // Extra space for strings
    )]
    pub token_data: Account<'info, TokenData>,
    
    #[account(
        init,
        payer = authority,
        mint::decimals = decimals,
        mint::authority = authority.key(),
    )]
    pub mint: Account<'info, Mint>,
    
    #[account(
        init,
        payer = authority,
        token::mint = mint,
        token::authority = authority,
    )]
    pub token_account: Account<'info, TokenAccount>,
    
    #[account(mut)]
    pub authority: Signer<'info>,
    
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts)]
pub struct EnableCrossChain<'info> {
    #[account(mut)]
    pub token_data: Account<'info, TokenData>,
    
    #[account(mut)]
    pub authority: Signer<'info>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct ConfigureBondingCurve<'info> {
    #[account(mut)]
    pub token_data: Account<'info, TokenData>,
    
    #[account(mut)]
    pub authority: Signer<'info>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct CalculatePrice<'info> {
    pub token_data: Account<'info, TokenData>,
}

#[derive(Accounts)]
pub struct SendCrossChainMessage<'info> {
    pub token_data: Account<'info, TokenData>,
    
    #[account(mut)]
    pub authority: Signer<'info>,
    
    pub system_program: Program<'info, System>,
}

#[account]
pub struct TokenFactory {
    pub authority: Pubkey,
    pub token_count: u64,
}

#[account]
pub struct TokenData {
    pub mint: Pubkey,
    pub name: String,
    pub symbol: String,
    pub decimals: u8,
    pub metadata_uri: String,
    pub authority: Pubkey,
    pub initial_supply: u64,
    pub token_id: u64,
    pub cross_chain_enabled: bool,
    pub cross_chain_info: CrossChainInfo,
    pub bonding_curve: BondingCurve,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Default)]
pub struct CrossChainInfo {
    pub wormhole_emitter: Pubkey,
    pub supported_chains: Vec<u16>,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Default)]
pub struct BondingCurve {
    pub enabled: bool,
    pub curve_type: u8, // 0: Linear, 1: Exponential, 2: Bancor
    pub base_price: u64,
    pub slope: u64,
    pub reserve_ratio: u16, // For Bancor formula, represented as parts per 1000
}

#[event]
pub struct TokenCreatedEvent {
    pub token_id: u64,
    pub mint: Pubkey,
    pub name: String,
    pub symbol: String,
    pub decimals: u8,
    pub initial_supply: u64,
}

#[event]
pub struct CrossChainEnabledEvent {
    pub token_id: u64,
    pub mint: Pubkey,
    pub wormhole_emitter: Pubkey,
    pub supported_chains: Vec<u16>,
}

#[event]
pub struct BondingCurveConfiguredEvent {
    pub token_id: u64,
    pub mint: Pubkey,
    pub curve_type: u8,
    pub base_price: u64,
    pub slope: u64,
    pub reserve_ratio: u16,
}

#[event]
pub struct PriceCalculatedEvent {
    pub token_id: u64,
    pub mint: Pubkey,
    pub supply: u64,
    pub amount: u64,
    pub price: u64,
}

#[event]
pub struct CrossChainMessageSentEvent {
    pub token_id: u64,
    pub mint: Pubkey,
    pub target_chain: u16,
    pub payload: Vec<u8>,
}

#[error_code]
pub enum TokenFactoryError {
    #[msg("Invalid authority for this operation")]
    InvalidAuthority,
    
    #[msg("Cross-chain functionality not enabled")]
    CrossChainNotEnabled,
    
    #[msg("Unsupported target chain")]
    UnsupportedChain,
    
    #[msg("Invalid curve type")]
    InvalidCurveType,
    
    #[msg("Invalid reserve ratio")]
    InvalidReserveRatio,
    
    #[msg("Bonding curve not enabled")]
    BondingCurveNotEnabled,
}
