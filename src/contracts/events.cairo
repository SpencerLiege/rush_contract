//! RushEvents contract and implementation
//!
//! This contract manages prediction events, allowing users to place bets on various outcomes and claim rewards based on the results. It includes functionalities for adding, starting, ending, resolving, and archiving events, as well as placing bets and claiming rewards.
//! The contract ensures secure access control, proper event state management, and accurate reward calculations, while emitting relevant events for transparency and tracking.
//! The implementation includes internal functions for validating admin access, checking event existence, managing event participants, and verifying bet and claim conditions.
//! 
//! # Exam

#[starknet::contract]
pub mod RushEvents {

    use starknet::{get_block_timestamp, get_contract_address,get_caller_address, ContractAddress};
    use starknet::event::EventEmitter;
    use crate::interfaces::{IRushEvents, IRushERC20Dispatcher, IRushERC20DispatcherTrait};
    use crate::types::{Config, PredictionEvent, Bet, EventResult};
    use crate::errors::Errors;
    use crate::events::{EventAdded, EventStarted, EventEnded, EventResolved, EventArchived, BetPlaced, RewardClaimed};
    use starknet::storage::{Map, StorageMapWriteAccess, StorageMapReadAccess, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePath, StoragePathEntry};

    const FEE_DENOM: u256 = 1000;

    #[storage]
    struct Storage {
        config: Config,
        event: Map<u64, PredictionEvent>,
        event_participant: Map<(u64, u64), ContractAddress>,
        event_participants_count: Map<u64, u64>,
        event_participant_exists: Map<(u64, ContractAddress), bool>,
        user_bet: Map<(ContractAddress, u64), Bet>,
        user_event_count: Map<ContractAddress, u64>,
        user_events: Map<(ContractAddress, u64), u64>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        EventAdded: EventAdded,
        EventStarted: EventStarted,
        EventEnded: EventEnded,
        EventResolved: EventResolved,
        EventArchived: EventArchived,
        BetPlaced: BetPlaced,
        RewardClaimed: RewardClaimed
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
    impl RushEventImpl of IRushEvents<ContractState> {


        fn add_event(
            ref self: ContractState, 
            name: ByteArray, 
            category: ByteArray, 
            binary: bool,
            home_team: ByteArray, 
            away_team: ByteArray, 
            start_time: u64, 
            end_time: u64,
            option_a: ByteArray,
            option_b: ByteArray,
            option_c: ByteArray,
            option_d: ByteArray,
        ) ->  u64 {
            // Verify admin access
            self._is_admin();

            // get config data
            let mut config: Config = self.config.read();

            let event: PredictionEvent = PredictionEvent { 
                event_id: config.id, 
                name: name.clone(), 
                category: category.clone(), 
                binary: binary,
                start_time: start_time, 
                end_time: end_time, 
                started: false, 
                ended: false, 
                resolved: false, 
                archived: false, 
                total_pool: 0, 
                result: None,
                yes_pool: 0,
                no_pool: 0,
                home_team: home_team,
                away_team: away_team,
                option_a: option_a,
                option_b: option_b,
                option_c: option_c,
                option_d: option_d,
                option_a_pool: 0,
                option_b_pool: 0,
                option_c_pool: 0,
                option_d_pool: 0,
                participants: 0
            };

            // save the event
            self.event.write(config.id, event);
            // increment the event id for next event
            config.id += 1;
            self.config.write(config);

            self.emit(EventAdded {
                event_id: config.id - 1,
                name,
                category,
                start_time,
                end_time
            });
            
            config.id - 1
        }

        fn start_event(ref self: ContractState, event_id: u64) -> bool {
            // verify admin access
            self._is_admin();

            //ensure the event exists
            self._event_exists(event_id);

            // get the event storage pointer
            let mut event: StoragePath = self.event.entry(event_id);

            // ensure current time is greater or equal to start time
            let now: u64 = get_block_timestamp();
            assert(now >= event.start_time.read(), Errors::NOT_START_TIME);

            // validate event state
            assert(!event.started.read(), Errors::EVENT_ALREADY_STARTED);

            // start the event
            event.started.write(true);
            
            // emit an event
            self.emit(EventStarted {
                event_id,
                name: event.name.read().clone(),
                start_time: event.start_time.read(),
                started: true
            });

            event.started.read()

        }

        fn end_event(ref self: ContractState, event_id: u64) -> bool {

            // verify admin access
            self._is_admin();

            // ensure the event exists
            self._event_exists(event_id);

            // get the event storage pointer
            let mut event: StoragePath = self.event.entry(event_id);

            
            // ensure current time is greater or equal to start time
            let now: u64 = get_block_timestamp();
            assert(now >= event.end_time.read(), Errors::NOT_END_TIME);

            // validate the event state
            assert(event.started.read(), Errors::EVENT_NOT_STARTED);
            assert(!event.ended.read(), Errors::EVENT_ALREADY_ENDED);

            // end the event
            event.ended.write(true);

            // emit an event
            self.emit(EventEnded {
                event_id,
                name: event.name.read().clone(),
                end_time: event.start_time.read(),
                ended: true
            });

            event.ended.read()
        }

        fn resolve_event(ref self: ContractState, event_id: u64, result: EventResult) -> bool {

            // verify admin access
            self._is_admin();

            // ensure the event exists
            self._event_exists(event_id);

            // get the event storage pointer
            let mut event: StoragePath = self.event.entry(event_id);

            // validate event state
            assert(event.started.read(), Errors::EVENT_NOT_STARTED);
            assert(event.ended.read(), Errors::EVENT_NOT_ENDED);

            // resolve the event
            event.resolved.write(true);
            event.result.write(Option::Some(result));

            // collect the participants 
            let participants: Array<ContractAddress> = self._get_participants(event_id);

            for user in participants {
                let mut user_bet: Bet = self.user_bet.read((user, event_id));

                if event.binary.read() {
                    // seed the reward
                    let winning_pool: u256 = match result {
                        EventResult::Home => event.yes_pool.read(),
                        EventResult::Away => event.no_pool.read(),
                        EventResult::A => 0,
                        EventResult::B => 0,
                        EventResult::C => 0,
                        EventResult::D => 0,
                    };

                    let losing_pool: u256 = match result {
                        EventResult::Home => event.no_pool.read(),
                        EventResult::Away => event.yes_pool.read(),
                        EventResult::A => 0,
                        EventResult::B => 0,
                        EventResult::C => 0,
                        EventResult::D => 0,
                    };

                    // check pool status before calculating reward
                    if losing_pool > 0 && winning_pool > 0 {
                        // calculate reward
                        let reward: u256 = (user_bet.amount * losing_pool) / winning_pool + user_bet.amount;

                        // record user success on prediction
                        if user_bet.pick == result && result == EventResult::Home {
                            user_bet.won = true;
                            user_bet.reward = reward;
                            user_bet.profit = reward - user_bet.amount;
                        }   

                        if user_bet.pick == result && result == EventResult::Away {
                            user_bet.won = true;
                            user_bet.reward = reward;
                            user_bet.profit = reward - user_bet.amount
                        }
                    } else {
                        // refund the user if either pool is empty
                        let empty_reward: u256 = user_bet.amount;

                        // record user success
                        if user_bet.pick == result && result == EventResult::Home {
                            user_bet.won  = true;
                        }

                        if user_bet.pick == result && result == EventResult::Away {
                            user_bet.won = true;
                        }

                        user_bet.refund = true;
                        user_bet.reward = empty_reward;
                        user_bet.profit = empty_reward - user_bet.amount
                    }
                } else {
                    // For non binary options
                    let winning_pool: u256 = match result {
                        EventResult::A => event.option_a_pool.read(),
                        EventResult::B => event.option_b_pool.read(),
                        EventResult::C => event.option_c_pool.read(),
                        EventResult::D => event.option_d_pool.read(),
                        EventResult::Home => 0,
                        EventResult::Away => 0
                    };

                    let losing_pool: u256 = event.total_pool.read() - winning_pool;

                    // check pool status to before calculating reward
                    if losing_pool > 0 && winning_pool > 0 {
                        // calculate reward
                        let reward: u256 = (user_bet.amount * losing_pool) / winning_pool + user_bet.amount;
                        

                        // record user success on prediction
                        if user_bet.pick == result {
                            user_bet.won = true;
                            user_bet.reward = reward;
                            user_bet.profit = reward - user_bet.amount;
                        }
                    } else {
                        let empty_reward: u256 = user_bet.amount;
                        
                        if user_bet.pick == result {
                            user_bet.won = true;
                        }

                        user_bet.refund = true;
                        user_bet.reward = empty_reward;
                        user_bet.profit = empty_reward - user_bet.amount;
                    }

                }


                self.user_bet.write((user, event_id), user_bet)
            }


            self.emit(EventResolved {
                event_id,
                result,
                total_pool: event.total_pool.read(),
                participants: self.event_participants_count.read(event_id),
                resolved: true
            });
            
            event.resolved.read()
        }

        fn archive_event(ref self: ContractState, event_id: u64) {
            // verify admin access
            self._is_admin();

            // access the data from storage
            let mut event: StoragePath = self.event.entry(event_id);

            event.archived.write(true);

            // emit an event
            self.emit(EventArchived {
                event_id: event_id,
                archived: true
            })

        }

        fn place_bet(ref self: ContractState,  amount: u256, event_id: u64, pick: EventResult) {
            // confirm caller access
            self._is_bettable(event_id);

            // check if the user already bet on round
            let caller: ContractAddress = get_caller_address();
            let contract_address: ContractAddress = get_contract_address();

            let mut event: StoragePath = self.event.entry(event_id);
            let mut user_bet: StoragePath = self.user_bet.entry((caller, event_id));

            assert(user_bet.amount.read() == 0, Errors::BET_ALREADY_PLACED);
            
            assert(amount > 0, Errors::INVALID_AMOUNT);
            IRushERC20Dispatcher { contract_address:  self.config.token.read() }
                .transfer_from(caller, contract_address, amount);

            // update the event data
            if event.binary.read() {
                match pick {
                    EventResult::Home => {
                        let current: u256 = event.yes_pool.read();
                        event.yes_pool.write(current + amount);
                    },
                    EventResult::Away => {
                        let current: u256 = event.no_pool.read();
                        event.no_pool.write(current + amount);
                    },
                    _ => panic!("Invalid pick for binary event")
                }
            } else {
                match pick {
                    EventResult::A => {
                        let current: u256 = event.option_a_pool.read();
                        event.option_a_pool.write(current + amount);
                    },
                    EventResult::B => {
                        let current: u256 = event.option_b_pool.read();
                        event.option_b_pool.write(current + amount);
                    },
                    EventResult::C => {
                        let current: u256 = event.option_c_pool.read();
                        event.option_c_pool.write(current + amount);
                    },
                    EventResult::D => {
                        let current: u256 = event.option_d_pool.read();
                        event.option_d_pool.write(current + amount);
                    },
                    _ => panic!("Invalid pick for non binary option")
                }
            }

            // update total pool
            let total: u256 = event.total_pool.read();
            event.total_pool.write(total + amount);

            // increase particpants count
            let participants: u64 = event.participants.read();
            event.participants.write(participants + 1 );

            // add participant for event
            self._add_event_participant(event_id);

            // save the user event count and index
            let current_count: u64 = self.user_event_count.read(caller);

            self.user_events.write((caller, current_count), event_id);
            
            self.user_event_count.write(caller, current_count + 1);

            // save the user bet data
            let user: Bet = Bet {
                user: caller,
                event_id,
                amount,
                pick,
                won: false,
                reward: 0,
                profit: 0,
                refund: false,
                claimed: false
            };

            self.user_bet.write((caller, event_id), user);

            // emit the user bet event
            self.emit(BetPlaced {
                user: caller,
                event_id,
                pick,
                amount
            });

        }

        fn claim_reward(ref self: ContractState, event_id: u64) {
            // confirm status
            self._is_claimable(event_id);

            let caller: ContractAddress = get_caller_address();
            let mut user_bet: Bet = self.user_bet.read((caller, event_id));

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
            
            // mark as claimed
            user_bet.claimed = true;
            self.user_bet.write((caller, event_id), user_bet);

            // emit event
            self.emit(RewardClaimed {
                user: caller,
                event_id,
                amount: reward,
                fee
            })

        }

        fn get_event(self: @ContractState, event_id: u64) -> PredictionEvent {
            self.event.read(event_id)
        }

        fn get_event_count(self: @ContractState) -> u64 {
            let config: Config = self.config.read();
            config.id
        }

        fn get_user_bet(self: @ContractState, user: ContractAddress, event_id: u64) -> Bet {
            self.user_bet.read((user, event_id))
        }

        fn get_user_bet_count(self: @ContractState, user: ContractAddress) -> u64 {
            self.user_event_count.read(user)
        }

        fn get_user_event_by_index(self: @ContractState, user: ContractAddress, index: u64) -> u64 {
            self.user_events.read((user, index))
        }

    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        // Check if the caller of the function is the admin
        fn _is_admin(self: @ContractState)  {

            let config: Config = self.config.read();
            let caller: ContractAddress = get_caller_address();

            assert(config.admin == caller, Errors::NOT_ADMIN);
        }

        fn _event_exists(self: @ContractState, event_id: u64) {

            let event: PredictionEvent = self.event.read(event_id);

            assert(event.event_id != 0, Errors::EVENT_NOT_FOUND)
        }

        fn _add_event_participant(ref self: ContractState, event_id: u64) {
            let caller: ContractAddress = get_caller_address();

            // check if participant already exists
            let exists: bool = self.event_participant_exists.read((event_id, caller));
            assert(!exists, Errors::PARTICIPANTS_EXISTS);

            // get current participants count
            let mut count: StoragePath = self.event_participants_count.entry(event_id);
            let mut exists: StoragePath = self.event_participant_exists.entry((event_id, caller));
            let mut participant: StoragePath = self.event_participant.entry((event_id, count.read()));

            // store the next participant at next index
            participant.write(caller);

            // increase participants count
            count.write(count.read() + 1);

            // ensure particpant is present
            exists.write(true);
        }

        fn _get_participants(self: @ContractState, event_id: u64) -> Array<ContractAddress> {

            let count: u64 = self.event_participants_count.read(event_id);
            
            let mut list: Array<ContractAddress> = ArrayTrait::new();

            let mut i: u64 = 0;

            while i < count {
                let participant = self.event_participant.read((event_id, i));
                list.append(participant);
                i += 1;
            }

            list
        }

        fn _is_bettable(self: @ContractState, event_id: u64 )  {
            // fetch the round data
            let event: PredictionEvent = self.event.read(event_id);

            // check if round exists
            assert(event.event_id > 0, Errors::EVENT_NOT_FOUND);

            // ensure round has started
            assert(event.started, Errors::EVENT_NOT_STARTED);

            // ensure round has not ended
            assert(!event.ended, Errors::EVENT_ALREADY_ENDED);

            // ensure the round has not been resolved
            assert(!event.resolved, Errors::EVENT_ALREADY_RESOLVED);

            // ensure the caller is not a participant on the round already
            let caller: ContractAddress = get_caller_address();
            let exists: bool = self.event_participant_exists.read((event_id, caller));

            assert(!exists, Errors::CANNOT_PREDICT)

        }

        fn _is_claimable(self: @ContractState, event_id: u64) {
            // fetch user bet data
            let caller: ContractAddress = get_caller_address();
            let user_bet: Bet = self.user_bet.read((caller, event_id));

            // check if access is by user
            assert(caller == user_bet.user, Errors::UNAUTHORIZED);

            // check if user is won round
            assert(user_bet.won, Errors::LOST_ROUND);

            // check if already claimed
            assert(!user_bet.claimed, Errors::ALREADY_CLAIMED);
        }
    }
}
