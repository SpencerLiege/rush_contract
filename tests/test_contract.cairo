

// use rush_cairo::interfaces::IRushEventsDispatcherTrait;
// use rush_cairo::interfaces::IRushEventsDispatcher;
// use snforge_std::ContractClassTrait;
// use starknet::{ContractAddress, SyscallResultTrait, contract_address_const};
// use snforge_std::{DeclareResultTrait, declare};

// fn deploy_events() -> (IRushEventsDispatcher, ContractAddress) {
//     let contract = declare("RushEvents").unwrap_syscall().contract_class();

//     let owner: ContractAddress = contract_address_const::<'owner'>();
//     let constructor_calldata: Array<felt252> = array![owner.into()];

//     let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap_syscall();
//     let dispatcher = IRushEventsDispatcher { contract_address: contract_address };

//     (dispatcher, contract_address)
// }

// #[test]
// fn test_add_event() {
//     let (dispatcher, _contract_address) = deploy_events();

//     let event = dispatcher.add_event("Test", "Starknet", true, "", "", 179999388838, 17888888888, "", "", "", "");

//     assert(event == 0, "First should retrurn ");
// }