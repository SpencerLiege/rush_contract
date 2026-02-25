#[starknet::contract]
pub mod RushQuest {

    use starknet::{ get_contract_address,get_caller_address, ContractAddress};
    use starknet::event::EventEmitter;
    use crate::interfaces::{IRushQuest, IRushERC20Dispatcher, IRushERC20DispatcherTrait};
    use crate::types::{Config, Quest, UserGame};
    use crate::errors::Errors;
    use crate::events::{QuestCreated, QuestStarted, QuestEnded, QuestJoined, QuestRewardClaimed};
    use starknet::storage::{Map, StorageMapWriteAccess, StorageMapReadAccess, StoragePointerReadAccess, StoragePointerWriteAccess};
    
    #[storage]
    struct Storage {
        config: Config,

        quests: Map<u64, Quest>,
        user_quests: Map<(ContractAddress, u64), Quest>,
        user_quests_count: Map<ContractAddress, u64>,
        user_quests_id: Map<(ContractAddress, u64), u64>,

        user_game: Map<(ContractAddress, u64), UserGame>

        
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        QuestCreated: QuestCreated,
        QuestStarted: QuestStarted,
        QuestEnded: QuestEnded,
        QuestJoined: QuestJoined,
        QuestRewardClaimed: QuestRewardClaimed
    }

    #[constructor] 
    fn constructor(ref self: ContractState, admin: ContractAddress, treasury_fee: u256, treasury_address: ContractAddress, token: ContractAddress) {
        
        self.config.admin.write(admin);
        self.config.treasury_fee.write(treasury_fee);
        self.config.treasury_address.write(treasury_address);
        self.config.token.write(token);
        
    }

    #[abi(embed_v0)]
    impl RushQuestImpl of IRushQuest<ContractState> {

        fn create_quest(ref self: ContractState, name: ByteArray, entry_fee: u256, stake: u256) {
            let caller: ContractAddress = get_caller_address();
            let mut config: Config = self.config.read();
            let quest_id: u64 = config.id + 1;

            // send the stake amount
            IRushERC20Dispatcher { contract_address: self.config.token.read() }
                .transfer_from(caller, get_contract_address(), stake);

            let quest: Quest = Quest {
                id: quest_id,
                user: caller,
                title: name,
                entry_fee: entry_fee,
                stake: stake,
                participants: 0,
                started: false,
                ended: false
            };

            self.quests.write(quest_id, quest);
            
            self.user_quests_count.write(caller, self.user_quests_count.read(caller) + 1);
            self.user_quests_id.write((caller, self.user_quests_count.read(caller)), quest_id);
            config.id = quest_id;
            self.config.write(config);
            // Emit event here
            
            self.emit( QuestCreated {
                quest_id,
                user: caller,
                title: self.quests.read(quest_id).title,
                entry_fee,
                stake
            });
        }

        fn start_quest(ref self: ContractState, quest_id: u64) {

            let mut quest = self.quests.read(quest_id);

            // confirm auth
            self._is_owner(quest.user);

            // ensure quest has not started/ended
            assert(!quest.started, Errors::EVENT_ALREADY_STARTED);
            assert(!quest.ended, Errors::EVENT_ALREADY_ENDED);

            quest.started = true;
            self.quests.write(quest_id, quest);

            // emit event here
            self.emit(QuestStarted {
                quest_id,
                started: true
            });
        }

        fn end_quest(ref self: ContractState, quest_id: u64) {
            let mut quest: Quest = self.quests.read(quest_id);

            // confirm auth
            self._is_owner(quest.user);

            // ensure the quest has started and not ended
            assert(quest.started, Errors::EVENT_NOT_STARTED);
            assert(!quest.ended, Errors::EVENT_ALREADY_ENDED);

            quest.ended = true;
            self.quests.write(quest_id, quest);

            self.emit(QuestEnded {
                quest_id,
                ended: true,
                participants: self.quests.read(quest_id).participants
            })
        }
        

        fn join_quest(ref self: ContractState, quest_id: u64) {
            // get the quest data
            let mut quest: Quest = self.quests.read(quest_id);
            let caller: ContractAddress = get_caller_address();
            let contract_address: ContractAddress = get_contract_address();

            assert(quest.started, Errors::EVENT_NOT_STARTED);
            assert(!quest.ended, Errors::EVENT_ALREADY_ENDED);

            // pay fee
            IRushERC20Dispatcher { contract_address: self.config.token.read() }
                .transfer_from(caller, contract_address, quest.entry_fee);
            
            // add participant
            quest.participants += 1;
            self.quests.write(quest_id, quest);

            // user data
            let user_game: UserGame = UserGame {
                user: caller,
                quest_id,
                claimed: false,
                amount_claimed: 0
            };

            self.user_game.write((caller, quest_id), user_game);

            self.emit(QuestJoined {
                user: caller,
                quest_id,
                fee_paid: self.quests.read(quest_id).entry_fee
            });
        }

        fn claim_reward(ref self: ContractState, quest_id: u64, amount: u256) {
            // confirm access
            let caller: ContractAddress = get_caller_address();
            let mut user_game: UserGame = self.user_game.read((caller, quest_id));
            assert(caller == user_game.user, Errors::UNAUTHORIZED);

            // send the reward to the user
            IRushERC20Dispatcher { contract_address: self.config.token.read()}
                .transfer(caller, amount);

            // update the user data
            user_game.claimed = true;
            user_game.amount_claimed = amount;

            self.user_game.write((caller, quest_id), user_game);

            self.emit(QuestRewardClaimed {
                user: caller,
                quest_id,
                amount
            })

        }
        
        // QUERIES
        fn get_quest(self: @ContractState, quest_id: u64) -> Quest {

            self.quests.read(quest_id)
        }
        
        fn get_quest_count(self: @ContractState) -> u64 {
            self.config.id.read()
        }

        fn get_user_quest(self: @ContractState, user: ContractAddress, quest_id: u64) -> Quest {
            self.user_quests.read((user, quest_id))
        }

        fn get_user_quest_count(self: @ContractState, user: ContractAddress) -> u64 {
            self.user_quests_count.read(user)
        }

        fn get_user_quest_id(self: @ContractState, user: ContractAddress, index: u64) -> (u64, u64) {
            let user_id: u64 = self.user_quests_id.read((user, index));

            (index, user_id)
        }

        fn get_user_game(self: @ContractState, user: ContractAddress, quest_id: u64 ) -> UserGame {
            self.user_game.read((user, quest_id))
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        // check is caller is owner
        fn _is_owner(self: @ContractState, user: ContractAddress) {

            let caller: ContractAddress = get_caller_address();
            assert(user == caller, Errors::UNAUTHORIZED);

        }
    }
}