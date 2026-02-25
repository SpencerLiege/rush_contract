use crate::types::{Config, Leaderboard, PriceBet, PredictionEvent, Bet};
use crate::types::PricePrediction;
use crate::types::{EventResult, Direction, UserGame, Quest};
use starknet::ContractAddress;


/// Interface for Events prediction
/// 
/// The available traits in this interface includes:
/// - place_bet: for users to place their bets on an event
/// - claim_reward: for users to claim their rewards after an event is resolved
/// - add_event: for admin to add a new event
/// - start_event: for admin to start an event
/// - end_event: for admin to end an event
/// - resolve_event: for admin to resolve an event with the result
/// - archive_event: for admin to archive an event after it's resolved
/// - get_event: for users to get the details of an event
/// - get_event_count: for users to get the total number of events
/// - get_user_bet: for users to get their bet on a specific event
/// - get_user_bet_count: for users to get the total number of bets they have placed
///     
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

/// Interface for price prediction
/// 
/// The available traits in this interface includes:
/// - place_bet: for users to place their bets on a price prediction round
/// - claim_reward: for users to claim their rewards after a round is resolved
/// - execute_round: for admin to execute a round with the actual price
/// - get_round: for users to get the details of a specific round
/// - get_config: for users to get the configuration of the price prediction game
/// - get_next_round: for users to get the details of the next round
/// - get_live_round: for users to get the details of the currently live round
/// - get_ended_round: for users to get the details of the most recently ended round
/// - get_user_bet: for users to get their bet on a specific round
/// - get_user_round_by_index: for users to get the round id of a specific bet
/// - get_leaderboard: for users to get the leaderboard of the price prediction game
/// - get_players_count: for users to get the total number of players who have participated in the price prediction game
/// - get_player_by_index: for users to get the address of a player by their index in the list of players who have participated in the price prediction game
/// 
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


/// Interface for quests
/// 
/// The available traits in this interface includes:    
/// - create_quest: for admin to create a new quest
/// - start_quest: for admin to start a quest
/// - end_quest: for admin to end a quest
/// - join_quest: for users to join a quest
/// - claim_reward: for users to claim their rewards after a quest is ended
/// - get_quest: for users to get the details of a specific quest
/// - get_quest_count: for users to get the total number of quests
/// - get_user_quest: for users to get their quest details for a specific quest
/// - get_user_quest_count: for users to get the total number of quests they have joined
/// - get_user_quest_id: for users to get the quest id of a specific quest they have joined
/// - get_user_game: for users to get the game details of a specific quest they have joined
/// 
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


/// Interface for ERC20 token interactions
/// 
/// The available traits in this interface includes:    
/// - transfer: for users to transfer tokens to another address
/// - approve: for users to approve another address to spend their tokens
/// - transfer_from: for users to transfer tokens from another address to a recipient address, given that they have been approved to do so
/// - get_allowance: for users to check the amount of tokens that they have approved another address to spend on their behalf
/// Note: This interface is designed to be used with the Rush platform's ERC20 token, and may not be compatible with other ERC20 tokens without modification.
#[starknet::interface]
pub trait IRushERC20<TContractState> {
    fn transfer(ref self: TContractState, to: ContractAddress, amount: u256);
    fn approve(ref self: TContractState, to: ContractAddress, amount: u256);
    fn transfer_from(ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256);

    fn get_allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
}