use crate::types::{Config, Leaderboard, PriceBet, PredictionEvent, Bet};
use crate::types::PricePrediction;
use crate::types::{EventResult, Direction, UserGame, Quest};
use starknet::ContractAddress;


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
#[starknet::interface]
pub trait IRushPrice<TContractState> {
    // Execute messages
    fn place_bet(ref self: TContractState, round_id: u64, direction: Direction, amount: u256);
    fn claim_reward(ref self: TContractState, round_id: u64);

    fn execute_round(ref self: TContractState, price: u128) ;

    // query messages
    fn get_round(self: @TContractState, round_id: u64) -> PricePrediction;
    fn get_config(self: @TContractState) -> Config;

    fn get_next_round(self: @TContractState) -> PricePrediction;
    fn get_live_round(self: @TContractState) -> PricePrediction;
    fn get_ended_round(self: @TContractState) -> PricePrediction;

    fn get_user_bet(self: @TContractState, user: ContractAddress, round_id: u64) -> PriceBet;
    fn get_user_round_by_index(self: @TContractState, user: ContractAddress, index: u64) -> u64;

    fn get_leaderboard(self: @TContractState, user: ContractAddress) -> Leaderboard;
    fn get_players_count(self: @TContractState) -> u64;
    fn get_player_by_index(self: @TContractState, index: u64) -> ContractAddress;

}


// intterface for quest
#[starknet::interface]
pub trait IRushQuest<TContractState> {
    // execute messages
    fn create_quest(ref self: TContractState, name: ByteArray, entry_fee: u256, stake: u256);
    fn start_quest(ref self: TContractState, quest_id: u64);
    fn end_quest(ref self: TContractState, quest_id: u64);

    fn join_quest(ref self: TContractState, quest_id: u64);
    fn claim_reward(ref self: TContractState, quest_id: u64, amount: u256);

    // query messages
    fn get_quest(self: @TContractState, quest_id: u64) -> Quest;
    fn get_quest_count(self: @TContractState) -> u64;

    fn get_user_quest(self: @TContractState, user: ContractAddress, quest_id: u64) -> Quest;
    fn get_user_quest_count(self: @TContractState, user: ContractAddress) -> u64;
    fn get_user_quest_id(self: @TContractState, user: ContractAddress, index: u64) -> (u64, u64);

    fn get_user_game(self: @TContractState, user: ContractAddress, quest_id: u64) -> UserGame;
}


// Interface for transfers
#[starknet::interface]
pub trait IRushERC20<TContractState> {
    fn transfer(ref self: TContractState, to: ContractAddress, amount: u256);
    fn approve(ref self: TContractState, to: ContractAddress, amount: u256);
    fn transfer_from(ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256);

    fn get_allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
}