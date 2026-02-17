

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
}

#[derive(Drop, starknet::Event)]
pub struct EventEnded {
    #[key]
    pub event_id: u64,
    pub name: ByteArray,
    pub end_time: u64
}