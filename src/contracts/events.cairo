#[starknet::contract]
pub mod RushEvents {

    use starknet::{get_caller_address, ContractAddress};
    use crate::interfaces::IRushEvents;
    use crate::types::{Config, PredictionEvent, Bet, EventResult};
    use crate::errors::Errors;
    use crate::events::{EventAdded, EventStarted, EventEnded};
    use starknet::storage::{Map, StorageMapWriteAccess, StorageMapReadAccess, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePath, StoragePathEntry};

    #[storage]
    struct Storage {
        config: Config,
        event: Map<u64, PredictionEvent>,
        event_participant: Map<(u64, u64), ContractAddress>,
        event_participants_count: Map<u64, u64>,
        event_participant_exists: Map<(u64, ContractAddress), bool>,
        user_bet: Map<(ContractAddress, u64), Bet>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        EventAdded: EventAdded,
        EventStarted: EventStarted,
        EventEnded: EventEnded
    }


    #[constructor]
    fn constructor() {}

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
                start_time: 0, 
                end_time: 0, 
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
                option_d_pool: 0
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

            // validate event state
            assert(!event.started.read(), Errors::EVENT_ALREADY_STARTED);

            // start the event
            event.started.write(true);
            
            // emit an event
            self.emit(EventStarted {
                event_id,
                name: event.name.read().clone(),
                start_time: event.start_time.read()
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

            // validate the event state
            assert(event.started.read(), Errors::EVENT_NOT_STARTED);
            assert(!event.ended.read(), Errors::EVENT_ALREADY_ENDED);

            // end the event
            event.ended.write(true);

            // emit an event
            self.emit(EventEnded {
                event_id,
                name: event.name.read().clone(),
                end_time: event.start_time.read()
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
            assert(event.start_time.read(), Errors::EVENT_NOT_STARTED);
            assert(event.end_time.read(), Errors::EVENT_NOT_ENDED);

            // resolve the event
            event.resolved.write(true);
            event.result.write(result);

            // collect the participants 
            let participants: Array<ContractAddress> = self._get_participants(event_id);

            for user in participants {
                let mut user_bet: StoragePath = self.user_bet.entry((user, event_id));

                if event.binary.read() {
                    // seed the reward
                    let winning_pool: u256 = match result {
                        EventResult::Home => event.yes_pool.read(),
                        EventResult::Away => event.no_pool.read(),
                    };

                    let losing_pool: u256 = match result {
                        EventResult::Home => event.no_pool.read(),
                        EventResult::Away => event.yes_pool.read(),
                    };

                    // check pool status before calculating reward
                    if losing_pool > 0 && winning_pool > 0 {
                        // calculate reward
                        let reward: u256 = (user_bet.amount * losing_pool) / winning_pool + user_bet.amount;

                        // record user success on prediction
                        if user_bet.pick == EventResult::Home && result == EventResult::Home {
                            user_bet.
                        }   
                    }
                } else {

                }
            }
            
        }

        // fn archive_event(ref self: ContractState) {}

        // fn place_bet(ref self: ContractState) {}

        // fn get_event(self: @ContractState) {}

        // fn get_all_events(self: @ContractState) {}

        // fn get_user_bet(self: @ContractState) {}

        // fn get_user_bets(self: @ContractState) {}
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
    }
}
