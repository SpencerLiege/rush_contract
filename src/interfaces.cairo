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
    fn get_all_events(self: @TContractState) -> Array<PredictionEvent>;
    
    fn get_user_bet(self: @TContractState, user: ContractAddress, event_id: u64) -> Bet;
    fn get_user_bets(self: @TContractState, user: ContractAddress) -> Array<Bet>;

}

// interface for price




// intterface for quest