/// This file contains the data structres used in the prediction market contract.
/// 
/// It includes structs and enums for the configuarations, events prediction, events bets, prrice prediction, price bets, leaderboard, quests, and user games
/// 

use starknet::ContractAddress;

#[derive(Drop, Serde, Copy, starknet::Store)] 
pub struct Config {
    pub admin: ContractAddress,
    pub treasury_fee: u256,
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
    pub participants: u64
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
    pub refund: bool,
    pub claimed: bool
}


#[derive(Drop, Serde, PartialEq, Copy, starknet::Store)]
#[allow(starknet::store_no_default_variant)]
pub enum Direction {
    Up,
    Down
}

#[derive(Drop, Serde, PartialEq, Copy, starknet::Store)]
#[allow(starknet::store_no_default_variant)]
pub enum RoundResult {
    Up,
    Down,
    Draw
}

#[derive(Drop, Serde, starknet::Store)]
pub struct PricePrediction {
    pub id: u64,
    pub bull_pool: u256,
    pub bear_pool: u256,
    pub total_pool: u256,
    pub start_time: u64,
    pub lock_time: u64,
    pub end_time: u64,
    pub start_price: u128,
    pub lock_price: u128,
    pub end_price: u128,
    pub started: bool,
    pub locked: bool,
    pub ended: bool,
    pub executed: bool,
    pub result: Option<RoundResult>,
    pub participants: u64
}

#[derive(Drop, Serde, Copy,  starknet::Store)]
pub struct PriceBet {
    pub user: ContractAddress,
    pub id: u64,
    pub amount: u256,
    pub direction: Direction,
    pub won: bool,
    pub reward: u256,
    pub claimed: bool,
    pub profit: u256,
    pub refund: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Leaderboard {
    pub user: ContractAddress,
    pub total_amount: u256,
    pub total_won: u64,
    pub total_lost: u64,
    pub total_up: u64,
    pub total_down: u64,
    pub profit: u256
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Quest {
    pub id: u64,
    pub user: ContractAddress,
    pub title: ByteArray,
    pub entry_fee: u256,
    pub stake: u256,
    pub participants: u64,
    pub started: bool,
    pub ended: bool
}

#[derive(Drop, Serde, starknet::Store)]
pub struct UserGame {
    pub user: ContractAddress ,
    pub quest_id: u64,
    pub claimed: bool,
    pub amount_claimed: u256
}