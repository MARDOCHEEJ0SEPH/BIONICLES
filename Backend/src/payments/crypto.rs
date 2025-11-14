use ethers::{
    prelude::*,
    providers::{Http, Provider},
    types::{Address, TransactionReceipt, H256, U256},
};
use std::sync::Arc;

use crate::models::{AppError, PaymentCurrency, PaymentNetwork};

//+------------------------------------------------------------------+
//| ERC20 Token ABI (simplified for Transfer event)                 |
//+------------------------------------------------------------------+

abigen!(
    IERC20,
    r#"[
        event Transfer(address indexed from, address indexed to, uint256 value)
        function balanceOf(address account) external view returns (uint256)
        function decimals() external view returns (uint8)
    ]"#
);

//+------------------------------------------------------------------+
//| Payment Processor                                                |
//+------------------------------------------------------------------+

pub struct PaymentProcessor {
    ethereum_provider: Arc<Provider<Http>>,
    polygon_provider: Arc<Provider<Http>>,
    payment_wallet: Address,
}

impl PaymentProcessor {
    /// Initialize payment processor
    pub async fn new(
        ethereum_rpc_url: String,
        polygon_rpc_url: String,
        payment_wallet_address: String,
    ) -> Result<Self, AppError> {
        log::info!("Initializing payment processor...");

        // Connect to Ethereum
        let ethereum_provider = Provider::<Http>::try_from(ethereum_rpc_url)
            .map_err(|e| AppError::Internal(format!("Failed to connect to Ethereum: {}", e)))?;

        // Connect to Polygon
        let polygon_provider = Provider::<Http>::try_from(polygon_rpc_url)
            .map_err(|e| AppError::Internal(format!("Failed to connect to Polygon: {}", e)))?;

        // Parse payment wallet address
        let payment_wallet: Address = payment_wallet_address
            .parse()
            .map_err(|e| AppError::Internal(format!("Invalid payment wallet address: {}", e)))?;

        log::info!("Payment wallet: {:?}", payment_wallet);

        Ok(PaymentProcessor {
            ethereum_provider: Arc::new(ethereum_provider),
            polygon_provider: Arc::new(polygon_provider),
            payment_wallet,
        })
    }

    /// Verify payment transaction
    pub async fn verify_payment(
        &self,
        tx_hash: &str,
        network: &PaymentNetwork,
        currency: &PaymentCurrency,
        expected_amount: f64,
    ) -> Result<PaymentVerification, AppError> {
        log::info!(
            "Verifying payment: {} on {} network ({})",
            tx_hash,
            network.as_str(),
            currency.as_str()
        );

        // Parse transaction hash
        let tx_hash: H256 = tx_hash
            .parse()
            .map_err(|e| AppError::PaymentVerificationFailed(format!("Invalid tx hash: {}", e)))?;

        // Get provider based on network
        let provider = match network {
            PaymentNetwork::Ethereum => &self.ethereum_provider,
            PaymentNetwork::Polygon => &self.polygon_provider,
        };

        // Get token contract address
        let token_address = self.get_token_address(network, currency);

        // Get transaction receipt
        let receipt = provider
            .get_transaction_receipt(tx_hash)
            .await
            .map_err(|e| AppError::PaymentVerificationFailed(format!("Failed to get receipt: {}", e)))?
            .ok_or_else(|| AppError::PaymentVerificationFailed("Transaction not found".to_string()))?;

        // Check if transaction succeeded
        if receipt.status != Some(1.into()) {
            return Err(AppError::PaymentVerificationFailed(
                "Transaction failed".to_string(),
            ));
        }

        // Parse transfer event
        let transfer = self.parse_transfer_event(&receipt, &token_address)?;

        // Verify recipient is our payment wallet
        if transfer.to != self.payment_wallet {
            return Err(AppError::PaymentVerificationFailed(format!(
                "Payment sent to wrong address. Expected: {:?}, Got: {:?}",
                self.payment_wallet, transfer.to
            )));
        }

        // Get token decimals
        let decimals = self.get_token_decimals(&token_address, provider).await?;

        // Convert amount from wei to human-readable
        let amount = self.wei_to_decimal(transfer.value, decimals);

        // Verify amount (allow 1% tolerance for gas fluctuations)
        let tolerance = expected_amount * 0.01;
        if amount < (expected_amount - tolerance) {
            return Err(AppError::PaymentVerificationFailed(format!(
                "Insufficient payment. Expected: {}, Got: {}",
                expected_amount, amount
            )));
        }

        log::info!(
            "Payment verified successfully: {} {} from {:?} to {:?}",
            amount,
            currency.as_str(),
            transfer.from,
            transfer.to
        );

        Ok(PaymentVerification {
            tx_hash: format!("{:?}", tx_hash),
            from_address: format!("{:?}", transfer.from),
            to_address: format!("{:?}", transfer.to),
            amount,
            currency: currency.as_str().to_string(),
            network: network.as_str().to_string(),
            block_number: receipt.block_number.map(|n| n.as_u64() as i64),
            confirmations: provider
                .get_block_number()
                .await
                .ok()
                .and_then(|current| {
                    receipt.block_number.map(|tx_block| {
                        (current.as_u64() - tx_block.as_u64()) as i32
                    })
                })
                .unwrap_or(0),
            is_verified: true,
        })
    }

    /// Get token contract address based on network and currency
    fn get_token_address(&self, network: &PaymentNetwork, currency: &PaymentCurrency) -> Address {
        match (network, currency) {
            (PaymentNetwork::Ethereum, PaymentCurrency::USDT) => {
                "0xdAC17F958D2ee523a2206206994597C13D831ec7".parse().unwrap()
            }
            (PaymentNetwork::Ethereum, PaymentCurrency::USDC) => {
                "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48".parse().unwrap()
            }
            (PaymentNetwork::Polygon, PaymentCurrency::USDT) => {
                "0xc2132D05D31c914a87C6611C10748AEb04B58e8F".parse().unwrap()
            }
            (PaymentNetwork::Polygon, PaymentCurrency::USDC) => {
                "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174".parse().unwrap()
            }
        }
    }

    /// Parse Transfer event from transaction receipt
    fn parse_transfer_event(
        &self,
        receipt: &TransactionReceipt,
        token_address: &Address,
    ) -> Result<TransferEvent, AppError> {
        // Find Transfer event log
        let log = receipt
            .logs
            .iter()
            .find(|log| {
                log.address == *token_address
                    && log.topics.len() == 3
                    && log.topics[0]
                        == H256::from_slice(
                            &ethers::utils::keccak256("Transfer(address,address,uint256)".as_bytes()),
                        )
            })
            .ok_or_else(|| {
                AppError::PaymentVerificationFailed("Transfer event not found".to_string())
            })?;

        // Parse topics
        let from = Address::from(log.topics[1]);
        let to = Address::from(log.topics[2]);

        // Parse data (amount)
        let value = U256::from_big_endian(&log.data);

        Ok(TransferEvent { from, to, value })
    }

    /// Get token decimals
    async fn get_token_decimals(
        &self,
        token_address: &Address,
        provider: &Arc<Provider<Http>>,
    ) -> Result<u8, AppError> {
        // USDT on Ethereum has 6 decimals
        // USDC on Ethereum has 6 decimals
        // USDT on Polygon has 6 decimals
        // USDC on Polygon has 6 decimals
        // For simplicity, return 6 (standard for stablecoins)
        Ok(6)
    }

    /// Convert wei to decimal
    fn wei_to_decimal(&self, wei: U256, decimals: u8) -> f64 {
        let divisor = 10_u64.pow(decimals as u32) as f64;
        wei.as_u128() as f64 / divisor
    }
}

//+------------------------------------------------------------------+
//| Transfer Event Structure                                         |
//+------------------------------------------------------------------+

struct TransferEvent {
    from: Address,
    to: Address,
    value: U256,
}

//+------------------------------------------------------------------+
//| Payment Verification Result                                      |
//+------------------------------------------------------------------+

#[derive(Debug, serde::Serialize)]
pub struct PaymentVerification {
    pub tx_hash: String,
    pub from_address: String,
    pub to_address: String,
    pub amount: f64,
    pub currency: String,
    pub network: String,
    pub block_number: Option<i64>,
    pub confirmations: i32,
    pub is_verified: bool,
}
