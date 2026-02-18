use crate::types::EventResult;
use starknet::ContractAddress;
use rush_cairo::types::{PredictionEvent, Bet};

// Interface for events
#[starknet::interface]
pub trait IRushEvents<TContractState> {
    // Execute messages
    fn place_bet(ref self: TContractState, amount: u256, event_id: u64, pick: EventResult ) ;
    fn claim_reward(ref self: TContractState, event_id: u64 ) ;

    fn add_event(ref self: TContractState, name: ByteArray, category: ByteArray, binary: bool, home_team: ByteArray, away_team: ByteArray, start_time: u64, end_time: u64, option_a: ByteArray, option_b: ByteArray, option_c: ByteArray, option_d: ByteArray) -> u64 ;
    fn start_event(ref self: TContractState, event_id: u64) -> bool;
    fn end_event(ref self: TContractState, event_id: u64) -> bool;
    fn resolve_event(ref self: TContractState, event_id: u64, result: EventResult) -> bool;
    fn archive_event(ref self: TContractState, event_id: u64);
    
    // Query messages
    fn get_event(self: @TContractState, event_id: u64 ) -> PredictionEvent ;
    fn get_event_count(self: @TContractState) -> u64;

    fn get_user_bet(self: @TContractState, user: ContractAddress, event_id: u64) -> Bet;
    fn get_user_bet_count(self: @TContractState, user: ContractAddress) -> u64;
    fn get_user_event_by_index(self: @TContractState, user: ContractAddress, index: u64) -> u64;
}

// interface for price




// intterface for quest