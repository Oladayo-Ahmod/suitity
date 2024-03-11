module dacade_deepbook::book {
    // Import necessary modules
    use sui::tx_context::{self, TxContext};
    use sui::object::{self, ID, UID};
    use sui::coin::{self, Coin};
    use sui::table::{self, Table};
    use sui::transfer;
    use sui::clock::{self, Clock};
    use std::string::{self, String};
    use std::option::{self, Option};

    // Error codes
    const ENoAccount: u64 = 1001;
    const EInsufficientBalance: u64 = 1002;
    const EOutOfBounds: u64 = 1003;
    const EInvalid: u64 = 1004;

    // Transaction struct
    struct Transaction {
        transaction_type: String,
        amount: u64,
        to: Option<address>,
        from: Option<address>,
    }

    // Account struct
    struct Account<phantom COIN> {
        id: UID,
        create_date: u64,
        updated_date: u64,
        current_balance: Coin<COIN>,
        account_address: address,
        transactions: vector<Transaction>,
    }

    // Transaction tracker struct
    struct TransactionTracker<phantom COIN> {
        id: UID,
        accounts: Table<address, Account<COIN>>,
    }

    // Create a new transaction tracker
    public fun create_tracker<COIN>(ctx: &mut TxContext) {
        let id = object::new(ctx);
        let accounts = table::new<address, Account<COIN>>(ctx);
        transfer::share_object(TransactionTracker<COIN> { 
            id,
            accounts,
        });
    }

    // Create a new account in the transaction tracker
    public fun create_account<COIN>(
        tracker: &mut TransactionTracker<COIN>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(!table::contains<address, Account<COIN>>(&tracker.accounts, sender), EInvalid);
        
        let account = Account {
            id: object::new(ctx),
            create_date: clock::timestamp_ms(clock),
            updated_date: 0,
            current_balance: coin::zero(ctx),
            account_address: sender,
            transactions: vector::empty<Transaction>(),
        };
        table::add(&mut tracker.accounts, sender, account);
    }

    // Record a deposit transaction
    public fun record_deposit<COIN>(
        tracker: &mut TransactionTracker<COIN>,
        clock: &Clock,
        amount: Coin<COIN>,
        ctx: &mut TxContext
    ){   
        let sender = tx_context::sender(ctx);
        assert!(table::contains<address, Account<COIN>>(&tracker.accounts, sender), ENoAccount);
        
        let account = table::borrow_mut<address, Account<COIN>>(&mut tracker.accounts, sender);
        let transaction = Transaction {
            transaction_type: string::utf8(b"deposit"),
            amount: coin::value(&amount),
            to: None,
            from: None,
        };
        coin::join(&mut account.current_balance, amount);
        account.updated_date = clock::timestamp_ms(clock);
        vector::push_back(&mut account.transactions, transaction);
    }
    
    // Record a withdrawal transaction
    public fun record_withdrawal<COIN>(
        tracker: &mut TransactionTracker<COIN>,
        clock: &Clock,
        amount: u64,
        ctx: &mut TxContext
    )
    {
        let sender = tx_context::sender(ctx);
        assert!(table::contains<address, Account<COIN>>(&tracker.accounts, sender), ENoAccount);
        
        let account = table::borrow_mut<address, Account<COIN>>(&mut tracker.accounts, sender);
        assert!(coin::value(&account.current_balance) >= amount, EInsufficientBalance);
        
        let transaction = Transaction {
            transaction_type: string::utf8(b"withdraw"),
            amount: amount,
            to: None,
            from: None,
        };
        vector::push_back(&mut account.transactions, transaction);
        account.updated_date = clock::timestamp_ms(clock);
        let transfer_coin = coin::split(&mut account.current_balance, amount, ctx);
        transfer::public_transfer(transfer_coin, sender);
    }

    // Record a transfer transaction
    public fun record_transfer<COIN>(
        tracker: &mut TransactionTracker<COIN>,
        clock: &Clock,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    )
    {
        let sender = tx_context::sender(ctx);
        assert!(table::contains<address, Account<COIN>>(&tracker.accounts, sender), ENoAccount);
        assert!(table::contains<address, Account<COIN>>(&tracker.accounts, recipient), EInvalid);
        assert!(sender != recipient, EInvalid);
        
        let sender_account = table::borrow_mut<address, Account<COIN>>(&mut tracker.accounts, sender);
        assert!(coin::value(&sender_account.current_balance) >= amount, EInsufficientBalance);
        
        sender_account.updated_date = clock::timestamp_ms(clock);
        let transaction = Transaction {
            transaction_type: string::utf8(b"transfer"),
            amount: amount,
            to: Some(recipient),
            from: Some(sender),
        };
        vector::push_back(&mut sender_account.transactions, transaction);
        
        let transfer_coin = coin::split(&mut sender_account.current_balance, amount, ctx);
        let recipient_account = table::borrow_mut<address, Account<COIN>>(&mut tracker.accounts, recipient);
        recipient_account.updated_date = clock::timestamp_ms(clock);
        vector::push_back(&mut recipient_account.transactions, transaction);
        coin::join(&mut recipient_account.current_balance, transfer_coin);
    }

    // Accessor functions

    // Get the creation date of the sender's account
    public fun account_create_date<COIN>(self: &TransactionTracker<COIN>, ctx: &mut TxContext) -> u64 {
        let sender = tx_context::sender(ctx);
        assert!(table::contains<address, Account<COIN>>(&self.accounts, sender), ENoAccount);
        let account = table::borrow<address, Account<COIN>>(&self.accounts, sender);
        account.create_date
    }

    // Get the last updated date of the sender's account
    public fun account_updated_date<COIN>(self: &TransactionTracker<COIN>, ctx: &mut TxContext) -> u64 {
        let sender = tx_context::sender(ctx);
        assert!(table::contains<address, Account<COIN>>(&self.accounts, sender), ENoAccount);
        let account = table::borrow<address, Account<COIN>>(&self.accounts, sender);
        account.updated_date
    }

    // Get
    module dacade_deepbook::book {
    // Import necessary modules
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, ID, UID};
    use sui::coin::{Self, Coin};
    use sui::table::{Table, Self};
    use sui::transfer;
    use sui::clock::{Self, Clock};
    use std::string::{Self, String};
    use std::vector;
    use std::option::{Option, none, some};

    // Error codes
    const ENoAccount: u64 = 0;
    const EInsufficientBalance: u64 = 1;
    const EOutOfBounds: u64 = 2;
    const EAccountNotFound: u64 = 3;

    // Transaction struct
    struct Transaction has store, copy, drop {
        transaction_type: String,
        amount: u64,
        to: Option<address>,
        from: Option<address>,
        timestamp: u64, // Added timestamp field
    }

    // Account struct
    struct Account<phantom COIN> has key, store {
        id: UID,
        name: String, // Added account name field
        create_date: u64,
        updated_date: u64,
        current_balance: Coin<COIN>,
        account_address: address,
        transactions: vector<Transaction>,
    }

    // Transaction tracker struct
    struct TransactionTracker<phantom COIN> has key {
        id: UID,
        name: String, // Added name field
        accounts: Table<address, Account<COIN>>,
    }

    // Create a new transaction tracker
    public fun create_tracker<COIN>(ctx: &mut TxContext, tracker_name: String) {
        let id = object::new(ctx);
        let accounts = table::new<address, Account<COIN>>(ctx);
        transfer::share_object(TransactionTracker<COIN> {
            id,
            name: tracker_name,
            accounts,
        });
    }

    // Create a new account in the transaction tracker
    public fun create_account<COIN>(
        tracker: &mut TransactionTracker<COIN>,
        account_name: String,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        assert!(
            !table::contains<address, Account<COIN>>(&tracker.accounts, tx_context::sender(ctx)),
            EInvalid
        );
        let account = Account {
            id: object::new(ctx),
            name: account_name,
            create_date: clock::timestamp_ms(clock),
            updated_date: 0,
            current_balance: coin::zero(ctx),
            account_address: tx_context::sender(ctx),
            transactions: vector::empty<Transaction>(),
        };
        table::add(&mut tracker.accounts, tx_context::sender(ctx), account);
    }

    // Record a deposit transaction
    public fun record_deposit<COIN>(
        tracker: &mut TransactionTracker<COIN>,
        clock: &Clock,
        amount: Coin<COIN>,
        ctx: &mut TxContext,
    ) {
        assert!(
            table::contains<address, Account<COIN>>(&tracker.accounts, tx_context::sender(ctx)),
            ENoAccount
        );
        let account = table::borrow_mut<address, Account<COIN>>(&mut tracker.accounts, tx_context::sender(ctx));
        let transaction = Transaction {
            transaction_type: String::from("deposit"),
            amount: coin::value(&amount),
            to: none(),
            from: none(),
            timestamp: clock::timestamp_ms(clock), // Added timestamp
        };
        coin::join(&mut account.current_balance, amount);
        account.updated_date = clock::timestamp_ms(clock);
        vector::push_back(&mut account.transactions, transaction);
    }

    // Record a withdrawal transaction
    public fun record_withdrawal<COIN>(
        tracker: &mut TransactionTracker<COIN>,
        clock: &Clock,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        assert!(
            table::contains<address, Account<COIN>>(&tracker.accounts, tx_context::sender(ctx)),
            ENoAccount
        );
        let account = table::borrow_mut<address, Account<COIN>>(&mut tracker.accounts, tx_context::sender(ctx));
        assert!(coin::value(&account.current_balance) >= amount, EInsufficientBalance);
        let transaction = Transaction {
            transaction_type: String::from("withdraw"),
            amount,
            to: none(),
            from: none(),
            timestamp: clock::timestamp_ms(clock), // Added timestamp
        };
        vector::push_back(&mut account.transactions, transaction);
        account.updated_date = clock::timestamp_ms(clock);
        let transfer_coin = coin::split(&mut account.current_balance, amount, ctx);
        transfer::public_transfer(transfer_coin, tx_context::sender(ctx));
    }

    // Record a transfer transaction
    public fun record_transfer<COIN>(
        tracker: &mut TransactionTracker<COIN>,
        clock: &Clock,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        assert!(
            table::contains<address, Account<COIN>>(&tracker.accounts, tx_context::sender(ctx)),
            ENoAccount
        );
        assert!(
            table::contains<address, Account<COIN>>(&tracker.accounts, recipient),
            EAccountNotFound
        );
        assert!(tx_context::sender(ctx) != recipient, EInvalid);
        let sender_account = table::borrow_mut<address, Account<COIN>>(&mut tracker.accounts, tx_context::sender(ctx));
        assert!(coin::value(&sender_account.current_balance) >= amount, EInsufficientBalance);
        sender_account.updated_date = clock::timestamp_ms(clock);
        let transaction = Transaction {
            transaction_type: String::from("transfer"),
            amount,
            to: some(recipient),
            from: some(tx_context::sender(ctx)),
            timestamp: clock::timestamp_ms(clock), // Added timestamp
        };
        vector::push_back(&mut sender_account.transactions, *&transaction);
        let transfer_coin = coin::split(&mut sender_account.current_balance, amount, ctx);
        let recipient_account = table::borrow_mut<address, Account<COIN>>(&mut tracker.accounts, recipient);
        recipient_account.updated_date = clock::timestamp_ms(clock);
        vector::push_back(&mut recipient_account.transactions, transaction);
        coin::join(&mut recipient_account.current_balance, transfer_coin);
    }

        // Get transaction history for the sender's account
    public fun get_transaction_history<COIN>(
        tracker: &TransactionTracker<COIN>,
        ctx: &mut TxContext,
    ) -> vector<(String, u64, Option<address>, Option<address>, u64)> {
        assert!(
            table::contains<address, Account<COIN>>(&tracker.accounts, tx_context::sender(ctx)),
            ENoAccount
        );
        let account = table::borrow<address, Account<COIN>>(&tracker.accounts, tx_context::sender(ctx));
        let mut history: vector<(String, u64, Option<address>, Option<address>, u64)> = vector::empty();

        for transaction in vector::iter(&account.transactions) {
            history.push_back((
                transaction.transaction_type.clone(),
                transaction.amount,
                transaction.to.clone(),
                transaction.from.clone(),
                transaction.timestamp,
            ));
        }

        history
    }

    // Accessor functions

    // Get the creation date of the sender's account
    public fun account_create_date<COIN>(self: &TransactionTracker<COIN>, ctx: &mut TxContext) -> u64 {
        assert!(
            table::contains<address, Account<COIN>>(&self.accounts, tx_context::sender(ctx)),
            ENoAccount
        );
        let account = table::borrow<address, Account<COIN>>(&self.accounts, tx_context::sender(ctx));
        account.create_date
    }

    // Get the last updated date of the sender's account
    public fun account_updated_date<COIN>(self: &TransactionTracker<COIN>, ctx: &mut TxContext) -> u64 {
        assert!(
            table::contains<address, Account<COIN>>(&self.accounts, tx_context::sender(ctx)),
            ENoAccount
        );
        let account = table::borrow<address, Account<COIN>>(&self.accounts, tx_context::sender(ctx));
        account.updated_date
    }

    // Get the current balance of the sender's account
    public fun account_balance<COIN>(self: &TransactionTracker<COIN>, ctx: &mut TxContext) -> u64 {
        assert!(
            table::contains<address, Account<COIN>>(&self.accounts, tx_context::sender(ctx)),
            ENoAccount
        );
        let account = table::borrow<address, Account<COIN>>(&self.accounts, tx_context::sender(ctx));
        coin::value(&account.current_balance)
    }

    // Get the number of accounts in the tracker
    public fun tracker_accounts_length<COIN>(self: &TransactionTracker<COIN>) -> u64 {
        table::length(&self.accounts)
    }

    // View a specific transaction of the sender's account
    public fun view_account_transaction<COIN>(
        tracker: &TransactionTracker<COIN>,
        index: u64,
        ctx: &mut TxContext,
    ) -> (String, u64, Option<address>, Option<address>, u64) {
        assert!(
            table::contains<address, Account<COIN>>(&tracker.accounts, tx_context::sender(ctx)),
            ENoAccount
        );
        let account = table::borrow<address, Account<COIN>>(&tracker.accounts, tx_context::sender(ctx));
        assert!(index < vector::length(&account.transactions), EOutOfBounds);
        let transaction = vector::get(&account.transactions, index);
        (
            transaction.transaction_type.clone(),
            transaction.amount,
            transaction.to.clone(),
            transaction.from.clone(),
            transaction.timestamp,
        )
    }
}


