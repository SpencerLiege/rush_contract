

use crate::types::RoundResult;
use crate::types::Direction;
use starknet::ContractAddress;
use crate::types::EventResult;

// PredictionEvent Events
#[derive(Drop, starknet::Event)]
pub struct EventAdded {
    #[key]
    pub event_id: u64,
    pub name: ByteArray,
    pub category: ByteArray,
    pub start_time: u64,
    pub end_time: u64
}

#[derive(Drop, starknet::Event)]
pub struct EventStarted {
    #[key]
    pub event_id: u64,
    pub name: ByteArray,
    pub start_time: u64,
    pub started: bool
}

#[derive(Drop, starknet::Event)]
pub struct EventEnded {
    #[key]
    pub event_id: u64,
    pub name: ByteArray,
    pub end_time: u64,
    pub ended: bool
}

#[derive(Drop, starknet::Event)] 
pub struct EventResolved {
    #[key]
    pub event_id: u64 ,
    pub result: EventResult,
    pub total_pool: u256,
    pub participants: u64,
    pub resolved: bool
}

#[derive(Drop, starknet::Event)]
pub struct EventArchived {
    pub event_id: u64 ,
    pub archived: bool
}

#[derive(Drop, starknet::Event)]
pub struct BetPlaced {
    #[key]
    pub user: ContractAddress,
    #[key]
    pub event_id: u64,
    pub pick: EventResult,
    pub amount: u256
}

#[derive(Drop, starknet::Event)]
pub struct RewardClaimed {
    #[key]
    pub user: ContractAddress,
    #[key]
    pub event_id: u64,
    pub amount: u256,
    pub fee: u256
}

// Price prediction events
#[derive(Drop, starknet::Event)]
pub struct RoundStarted {
    #[key]
    pub round_id: u64 ,
    pub start_time: u64,
    pub start_price: u128
}

#[derive(Drop, starknet::Event)]
pub struct RoundLocked {
    #[key]
    pub round_id: u64 ,
    pub lock_time: u64,
    pub lock_price: u128
}

#[derive(Drop, starknet::Event)]
pub struct RoundEnded {
    #[key]
    pub round_id: u64 ,
    pub end_time: u64,
    pub end_price: u128
}

#[derive(Drop, starknet::Event)]
pub struct RoundExecuted {
    #[key]
    pub round_id: u64,
    pub start_price: u128,
    pub lock_price: u128,
    pub end_price: u128,
    pub result: RoundResult,
    pub participants: u64
}

#[derive(Drop, starknet::Event)]
pub struct PriceBetPlaced {
    #[key]
    pub round_id: u64,
    pub user: ContractAddress,
    pub amount: u256,
    pub direction: Direction
}

#[derive(Drop, starknet::Event)]
pub struct PriceRewardClaimed  {
    #[key]
    pub user: ContractAddress,
    #[key]
    pub round_id: u64,
    pub amount: u256,
    pub fee: u256
}

// Quest events
#[derive(Drop, starknet::Event)] 
pub struct QuestCreated {
    #[key]
    pub quest_id: u64,
    pub user: ContractAddress,
    pub title: ByteArray,
    pub entry_fee: u256,
    pub stake: u256
}

#[derive(Drop, starknet::Event)]
pub struct QuestStarted {
    #[key]
    pub quest_id: u64,
    pub started: bool
}

#[derive(Drop, starknet::Event)]
pub struct QuestEnded {
    #[key]
    pub quest_id: u64,
    pub ended: bool,
    pub participants: u64
}

#[derive(Drop, starknet::Event)]
pub struct QuestJoined {
    #[key]
    pub user: ContractAddress,
    #[key]
    pub quest_id: u64,
    pub fee_paid: u256
}

#[derive(Drop, starknet::Event)]
pub struct QuestRewardClaimed {
    #[key]
    pub user: ContractAddress,
    #[key]
    pub quest_id: u64,
    pub amount: u256
}