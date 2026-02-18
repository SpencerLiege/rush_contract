pub mod Errors {
    pub const UNAUTHORIZED: felt252 = 'Unauthorized access';
    pub const NOT_ADMIN: felt252 = 'Caller is not admin';
    pub const EVENT_NOT_FOUND: felt252 = 'Event not found';
    pub const EVENT_ALREADY_STARTED: felt252 = 'Event already started';
    pub const EVENT_NOT_STARTED: felt252 = 'Event not started';
    pub const EVENT_ALREADY_ENDED: felt252 = 'Event already ended';
    pub const EVENT_NOT_ENDED: felt252 = 'Event not ended';
    pub const EVENT_ALREADY_RESOLVED: felt252 = 'Event already resolved';
    
    pub const PARTICIPANTS_EXISTS: felt252 = 'Participant already exists';
    pub const INVALID_AMOUNT: felt252 = 'Amount should be greater than 0';
    pub const BET_ALREADY_PLACED: felt252 = 'Bet already placed';
    pub const LOST_ROUND: felt252 = 'Lost round';
}