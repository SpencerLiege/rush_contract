#[starknet::contract]
pub mod RushPrice {
    use starknet::event::EventEmitter;
    use crate::interfaces::{IRushPrice,IRushERC20Dispatcher, IRushERC20DispatcherTrait};
    use crate::errors::Errors;
    use crate::types::{PricePrediction, PriceBet, Config, Direction, RoundResult, Leaderboard};
    use crate::events::{RoundStarted, RoundLocked, RoundEnded, RoundExecuted,PriceBetPlaced, PriceRewardClaimed};
    use starknet::{get_caller_address, get_contract_address, get_block_timestamp, ContractAddress};
    use starknet::storage::{Map, StorageMapWriteAccess, StorageMapReadAccess, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePath, StoragePathEntry};


    const FEE_DENOM: u256 = 1000;

    #[storage]
    struct Storage {
        config: Config,
       
        round: Map<u64, PricePrediction>,
        round_participant: Map<(u64, u64), ContractAddress>,
        round_participant_count: Map<u64, u64>,
        round_participant_exists: Map<(u64, ContractAddress), bool>,
        
        user_bet: Map<(ContractAddress, u64), PriceBet>,
        user_round_count: Map<ContractAddress, u64>,
        user_rounds: Map<(ContractAddress, u64), u64>,

        players: Map<u64, ContractAddress>,
        players_count: u64,
        player_index: Map<ContractAddress, u64>,
        leaderboard: Map<ContractAddress, Leaderboard>,

    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        RoundStarted: RoundStarted,
        RoundLocked: RoundLocked,
        RoundEnded: RoundEnded,
        RoundExecuted: RoundExecuted,
        BetPlaced: PriceBetPlaced,
        RewardClaimed: PriceRewardClaimed
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress, treasury_fee: u256, treasury_address: ContractAddress, token: ContractAddress) {
        self.config.admin.write(admin);
        self.config.treasury_fee.write(treasury_fee);
        self.config.treasury_address.write(treasury_address);
        self.config.token.write(token);
        self.config.id.write(1);
    }

    #[abi(embed_v0)]
    impl RustPriceImpl of IRushPrice<ContractState>  {
        
        fn execute_round(ref self: ContractState, price: u128) {
            let mut config: Config = self.config.read();
            self._is_admin();

            // automate round 
            if config.id == 1 {
                self._start_round(config.id, price);
            }

            if config.id > 1 {
                let prev_round_id: u64 = config.id - 1;
                let prev_round: PricePrediction = self.round.read(prev_round_id);

                let now: u64 = get_block_timestamp();

                assert(now >= prev_round.lock_time, Errors::NOT_LOCK_TIME);

                self._lock_round(prev_round.id, price);
                
                self._start_round(config.id, price);
            }

            if config.id > 2 {
                let end_prev_id: u64 = config.id - 2;
                let end_prev_round: PricePrediction = self.round.read(end_prev_id);

                let now: u64 = get_block_timestamp();

                assert(now >= end_prev_round.end_time, Errors::NOT_END_TIME);

                self._end_round(end_prev_round.id, price, self._get_participants(end_prev_round.id));
            }

            config.id += 1;
            self.config.write(config);
        }

        fn place_bet(ref self: ContractState, round_id: u64, direction: Direction, amount: u256) {

            // confirm the round is bettable
            self._is_bettable(round_id);

            // check if user already placed bet on round
            let caller: ContractAddress = get_caller_address();
            let contract_address: ContractAddress = get_contract_address(); 

            let mut round: StoragePath = self.round.entry(round_id);
            let mut user_bet: StoragePath = self.user_bet.entry((caller, round_id));

            assert(user_bet.amount.read() == 0, Errors::BET_ALREADY_PLACED);

            assert(amount > 0, Errors::INVALID_AMOUNT);
            IRushERC20Dispatcher { contract_address: self.config.token.read()}
                .transfer_from(caller, contract_address, amount);

            // save the user bet
            user_bet.user.write(caller);
            user_bet.id.write(round_id);
            user_bet.amount.write(amount);
            user_bet.direction.write(direction);
            user_bet.won.write(false);
            user_bet.reward.write(0);
            user_bet.profit.write(0);
            user_bet.refund.write(false);

            // update leaderboard
            let player_exists: u64 = self.player_index.read(caller);

            if player_exists == 0 {
                let count: u64 = self.players_count.read();
                let new_count = count + 1;

                self.players.write(new_count, caller);
                self.player_index.write(caller, new_count);
                self.players_count.write(new_count);

                let leaderboard: Leaderboard = Leaderboard { 
                    user: caller, 
                    total_amount: 0, 
                    total_won: 0, 
                    total_lost: 0, 
                    total_up: 0, 
                    total_down: 0, 
                    profit: 0
                };
                self.leaderboard.write(caller, leaderboard);
            }

            match direction {
                Direction::Up => {
                    round.bull_pool.write(round.bull_pool.read() + amount);
                },
                Direction::Down => {
                    round.bear_pool.write(round.bear_pool.read() + amount)
                }
            }
            round.total_pool.write(round.total_pool.read() + amount);
            round.participants.write(round.participants.read() + 1);

            // update user data on leaderboard
            let mut user_board: StoragePath = self.leaderboard.entry(caller);

            user_board.total_amount.write(user_board.total_amount.read() + amount);
            match direction {
                Direction::Up => {
                    user_board.total_up.write(user_board.total_up.read() + 1);
                },
                Direction::Down => {
                    user_board.total_down.write(user_board.total_down.read() + 1);
                }
            }


            self.emit(PriceBetPlaced {
                user: caller,
                round_id,
                amount,
                direction
            })
        }

        fn claim_reward(ref self: ContractState, round_id: u64) {
            // confitm status
            self._is_claimable(round_id);

            let caller: ContractAddress = get_contract_address();
            let mut  user_bet: PriceBet = self.user_bet.read((caller, round_id));

            // calculate fee
            let config: Config = self.config.read();
            let fee: u256  = (config.treasury_fee * user_bet.reward ) / FEE_DENOM;

            let reward: u256 = user_bet.reward - fee;

            let token: ContractAddress = config.token;
            let treasury: ContractAddress = config.treasury_address;

                        
            IRushERC20Dispatcher { contract_address:  token }
                .transfer(caller, reward);

            if user_bet.profit > 0 {
                IRushERC20Dispatcher { contract_address: token }
                    .transfer(treasury, fee);
            }

            user_bet.claimed =true;
            self.user_bet.write((caller, round_id), user_bet);

            // emit event
            self.emit(PriceRewardClaimed {
                user: caller,
                round_id,
                amount: user_bet.reward,
                fee
            })
        }

        fn get_round(self: @ContractState, round_id: u64) -> PricePrediction {
            self.round.read(round_id)
        }

        fn get_config(self: @ContractState) -> Config {
            self.config.read()
        }

        fn get_next_round(self: @ContractState) -> PricePrediction {
            let config: Config = self.config.read();
            self.round.read(config.id - 1)
        }

        fn get_live_round(self: @ContractState) -> PricePrediction {
            let config: Config = self.config.read();
            self.round.read(config.id - 2)
        }

        fn get_ended_round(self: @ContractState) -> PricePrediction {
            let config: Config = self.config.read();
            self.round.read(config.id - 3)
        }

        fn get_user_bet(self: @ContractState, user: ContractAddress, round_id: u64) -> PriceBet {
            self.user_bet.read((user, round_id))
        }

        fn get_user_round_by_index(self: @ContractState, user: ContractAddress, index: u64) -> u64 {
            self.user_rounds.read((user, index))
        }

        fn get_leaderboard(self: @ContractState, user: ContractAddress) -> Leaderboard {
            self.leaderboard.read(user)
        }

        fn get_players_count(self: @ContractState) -> u64 {
            self.players_count.read()
        }

        fn get_player_by_index(self: @ContractState, index: u64) -> ContractAddress {
            self.players.read(index)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait  {
        fn _start_round(ref self: ContractState, round_id: u64, price: u128) {

            // timestamps
            let beginning: u64 = get_block_timestamp();
            let lock: u64 = get_block_timestamp() + 300;
            let end: u64 = get_block_timestamp() + 600;

            // prepare the round data
            let round: PricePrediction = PricePrediction {
                id: round_id,
                bull_pool: 0,
                bear_pool: 0,
                total_pool: 0,
                start_time: beginning,
                lock_time: lock,
                end_time: end,
                start_price: price,
                lock_price: 0,
                end_price: 0,
                result: None,
                executed: false,
                started: true,
                locked: false,
                ended: false,
                participants: 0
            };
            
            self.round.write(round_id, round);

            self.emit(RoundStarted {
                round_id,
                start_time: beginning,
                start_price: price
            });

        }

        fn _lock_round(ref self: ContractState, round_id: u64, price: u128) {
            let mut round: StoragePath = self.round.entry(round_id);

            round.locked.write(true);
            round.lock_price.write(price);

            self.emit(RoundLocked {
                round_id,
                lock_time: round.lock_time.read(),
                lock_price: price
            });
        }

        fn _end_round(ref self: ContractState, round_id: u64, price: u128, participants: Array<ContractAddress>) {
            let mut round: StoragePath = self.round.entry(round_id);

            round.ended.write(true);
            round.end_price.write(price);

            // emit event for end round
            self.emit(RoundEnded {
                round_id,
                end_time: round.end_time.read(),
                end_price: round.end_price.read()
            });

            if round.lock_price.read() > round.end_price.read() {
                round.result.write(Some(RoundResult::Down));
            } else if round.lock_price.read() < round.end_price.read() {
                round.result.write(Some(RoundResult::Up));
            } else {
                round.result.write(Some(RoundResult::Draw));
            }

            round.executed.write(true);

            for user in participants {
                let mut user_bet: PriceBet = self.user_bet.read((user, round_id));
                let round_data: PricePrediction = self.round.read(round_id);

                // seed reward
                let winning_pool: u256 = match round_data.result {
                    Some(RoundResult::Up) => round_data.bull_pool,
                    Some(RoundResult::Down) => round_data.bear_pool,
                    Some(RoundResult::Draw) => 0,
                    None => 0,
                };

                let losing_pool: u256 = match round_data.result {
                    Some(RoundResult::Up) => round_data.bear_pool,
                    Some(RoundResult::Down) => round_data.bull_pool,
                    Some(RoundResult::Draw) => 0,
                    None => 0,
                };

                // check status
                if losing_pool > 0 && winning_pool > 0 {
                    // calculate reward
                    let reward: u256 = (user_bet.amount * losing_pool) / winning_pool + user_bet.amount;

                    if user_bet.direction == Direction::Up && round_data.result == Some(RoundResult::Up) {
                        user_bet.won = true;
                        user_bet.reward = reward;
                        user_bet.profit = reward - user_bet.amount;
                    }

                    if user_bet.direction == Direction::Down && round_data.result == Some(RoundResult::Down) {
                        user_bet.won = true;
                        user_bet.reward = reward;
                        user_bet.profit = reward - user_bet.amount;
                    }
                } else {
                    let mut empty_reward = user_bet.amount;

                    // record the user bet as success
                    if user_bet.direction == Direction::Up && round_data.result == Some(RoundResult::Up) {
                        user_bet.won = true;
                    }

                    if user_bet.direction == Direction::Down && round_data.result == Some(RoundResult::Down) {
                        user_bet.won = true;
                    }

                    user_bet.refund = true;
                    user_bet.reward = empty_reward;
                    user_bet.profit = empty_reward - user_bet.amount;
                }
                
                // implement leaderboard

                let mut user_data: Leaderboard = self.leaderboard.read(user);

                if user_bet.won {
                    user_data.total_won = user_data.total_won + 1;
                    user_data.profit = user_bet.profit + user_data.profit;
                } else {
                    user_data.total_lost = user_data.total_lost + 1;
                }

                self.leaderboard.write(user, user_data);

            }

            if round.result.read() == Some(RoundResult::Draw) {
                let config: Config = self.config.read();

                IRushERC20Dispatcher { contract_address: config.token }
                    .transfer(config.treasury_address, round.total_pool.read());
            }

            let final_round_data: PricePrediction = self.round.read(round_id);

            self.emit(RoundExecuted {
                round_id,
                start_price: final_round_data.start_price,
                lock_price: final_round_data.lock_price,
                end_price: final_round_data.end_price,
                result: final_round_data.result.unwrap(),
                participants: final_round_data.participants
            });

        }

        fn _is_admin(self: @ContractState) {
            let config: Config = self.config.read();
            let caller: ContractAddress = get_caller_address();

            assert(config.admin == caller, Errors::NOT_ADMIN);

        }

        fn _is_bettable(self: @ContractState, round_id: u64) {
            // fetch the round data
            let round: PricePrediction = self.round.read(round_id);

            // check if round exists
            assert(round.id > 0, Errors::EVENT_NOT_FOUND);

            // ensure the round has started and time not lock
            assert(round.started, Errors::NOT_START_TIME);
            assert(!round.locked, Errors::ROUND_LOCKED);
            assert(!round.ended, Errors::ROUND_ENDED);

            // ensure the caller is not a participant on the round already
            let caller: ContractAddress = get_caller_address();
            let exists: bool = self.round_participant_exists.read((round_id, caller));

            assert(!exists, Errors::CANNOT_PREDICT);

        }

    
        fn _is_claimable(self: @ContractState, round_id: u64) {
            // fetch user bet data
            let caller: ContractAddress = get_caller_address();
            let user_bet: PriceBet = self.user_bet.read((caller, round_id));

            // check if access is by user
            assert(caller == user_bet.user, Errors::UNAUTHORIZED);

            // check if user is won round
            assert(user_bet.won, Errors::LOST_ROUND);

            // check if already claimed
            assert(!user_bet.claimed, Errors::ALREADY_CLAIMED);
        }

        fn _add_event_participant(ref self: ContractState, round_id: u64) {
            let caller: ContractAddress = get_caller_address();

            // check if participant already exists
            let exists: bool = self.round_participant_exists.read((round_id, caller));
            assert(!exists, Errors::PARTICIPANTS_EXISTS);

            // get current participants count
            let mut count: StoragePath = self.round_participant_count.entry(round_id);
            let mut exists: StoragePath = self.round_participant_exists.entry((round_id, caller));
            let mut participant: StoragePath = self.round_participant.entry((round_id, count.read()));

            // store the next participant at next index
            participant.write(caller);

            // increase participants count
            count.write(count.read() + 1);

            // ensure particpant is present
            exists.write(true);
        }

        fn _get_participants(self: @ContractState, round_id: u64) -> Array<ContractAddress> {

            let count: u64 = self.round_participant_count.read(round_id);
                
            let mut list: Array<ContractAddress> = ArrayTrait::new();

            let mut i: u64 = 0;

            while i < count {
                let participant: ContractAddress = self.round_participant.read((round_id, i));
                list.append(participant);
                i += 1;
            }

            list
        }

       }


}