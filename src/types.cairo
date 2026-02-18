

use starknet::ContractAddress;

#[derive(Drop, Serde, Copy, starknet::Store)] 
pub struct Config {
    pub admin: ContractAddress,
    pub treasury_fee: u64,
    pub treasury_address: ContractAddress,
    pub id: u64,
    pub token: ContractAddress
}

#[derive(Drop, Serde, Copy, starknet::Store, PartialEq)]
#[allow(starknet::store_no_default_variant)]
pub enum EventResult {
    Home,
    Away, 
    A,
    B,
    C,
    D,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct PredictionEvent {
    pub event_id: u64,
    pub name: ByteArray,
    pub category: ByteArray,
    pub binary: bool,
    pub start_time: u64,
    pub end_time:u64,
    pub started: bool,
    pub ended: bool,
    pub resolved: bool,
    pub archived: bool,
    pub total_pool: u256,
    pub result: Option<EventResult>,
    pub yes_pool: u256,
    pub no_pool: u256,
    pub home_team: ByteArray,
    pub away_team: ByteArray,
    pub option_a: ByteArray,
    pub option_b: ByteArray,
    pub option_c: ByteArray,
    pub option_d: ByteArray,
    pub option_a_pool: u256,
    pub option_b_pool: u256,
    pub option_c_pool: u256,
    pub option_d_pool: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Bet {
    pub user: ContractAddress,
    pub event_id: u64,
    pub amount: u256,
    pub pick: EventResult,
    pub won: bool,
    pub reward: u256,
    pub profit: u256,
    pub refund: bool
}


