#[lint_allow(self_transfer)] // Allowing self transfer lint
#[allow(unused_use)] // Allowing unused imports


module dacade_deepbook::book {
    // Import necessary modules
    use sui::tx_context::{Self, TxContext}; // Importing TxContext module
    use sui::object::{Self, ID, UID}; // Importing object module with specific items
    use sui::coin::{Self, Coin}; // Importing Coin module
    use sui::table::{Table, Self}; // Importing Table module
    use sui::transfer; // Importing transfer module
    use sui::clock::{Self, Clock}; // Importing Clock module
    use std::string::{Self, String}; // Importing String module
    use std::vector; // Importing vector module
    use std::option::{Option, none, some}; // Importing Option module with specific items

    // Error codes
    const ACCOUNT_NOT_FOUND: u64 = 0; // error code for account thet does not exist
    const INSUFFICIENT_BALANCE: u64 = 1; // error code insufficient balance
    const INVALID_INDEX: u64 = 2; // error code for invalid index
    const INVALID_OPERATION: u64 = 3; // error code for invalid operation


    // Transaction struct
    struct Transaction has store, copy, drop { // Defining the Transaction struct
        transaction_type: String, // Type of transaction
        amount: u64, // Amount involved in the transaction
        to: Option<address>, // Receiver address if applicable
        from: Option<address> // Sender address if applicable
    }

    // Account struct
    struct Account<phantom COIN> has key, store { // Defining the Account struct
        id: UID, // Account ID
        create_date: u64, // Creation date of the account
        updated_date: u64, // Last updated date of the account
        current_balance: Coin<COIN>, // Current balance in the account
        account_address: address, // Address of the account
        transactions: vector<Transaction> // List of transactions associated with the account
    }

    // Transaction tracker struct
    struct TransactionTracker<phantom COIN> has key { // Defining the TransactionTracker struct
        id: UID, // Tracker ID
        accounts: Table<address, Account<COIN>> // Table to store accounts
    }

    // Create a new transaction tracker
    public fun create_tracker<COIN>(ctx: &mut TxContext) { // Function to create a new transaction tracker
        let id = object::new(ctx); // Generate a new object ID
        let accounts = table::new<address, Account<COIN>>(ctx); // Create a new table for accounts
        transfer::share_object(TransactionTracker<COIN> { // Share the transaction tracker object
            id,
            accounts
        })
    }

    // Create a new account in the transaction tracker
    public fun create_account<COIN>(
        tracker: &mut TransactionTracker<COIN>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!table::contains<address, Account<COIN>>(&tracker.accounts, tx_context::sender(ctx)), INVALID_INDEX); // Asserting if the account already exists
        let account = Account { // Creating a new account
            id: object::new(ctx),
            create_date: clock::timestamp_ms(clock),
            updated_date: 0,
            current_balance: coin::zero(ctx),
            account_address: tx_context::sender(ctx),
            transactions: vector::empty<Transaction>()
        };
        table::add(&mut tracker.accounts, tx_context::sender(ctx), account); // Adding the account to the tracker
    }

    // Record a deposit transaction
    public fun record_deposit<COIN>(
        tracker: &mut TransactionTracker<COIN>,
        clock: &Clock,
        amount: Coin<COIN>,
        ctx: &mut TxContext
    ){   
        assert!(table::contains<address, Account<COIN>>(&tracker.accounts, tx_context::sender(ctx)), ACCOUNT_NOT_FOUND); // Asserting if the account exists
        let account = table::borrow_mut<address, Account<COIN>>(&mut tracker.accounts, tx_context::sender(ctx)); // Borrowing mutable reference to the account
        let transaction = Transaction { // Creating a deposit transaction
            transaction_type: string::utf8(b"deposit"),
            amount: coin::value(&amount),
            to: none(),
            from: none()
        };
        coin::join(&mut account.current_balance, amount); // Updating the account balance
        account.updated_date = clock::timestamp_ms(clock); // Updating the account's updated date
        vector::push_back(&mut account.transactions, transaction); // Recording the transaction
    }
    
    // Record a withdrawal transaction
    public fun record_withdrawal<COIN>(
        tracker: &mut TransactionTracker<COIN>,
        clock: &Clock,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(table::contains<address, Account<COIN>>(&tracker.accounts, tx_context::sender(ctx)), ACCOUNT_NOT_FOUND); // Asserting if the account exists
        let account = table::borrow_mut<address, Account<COIN>>(&mut tracker.accounts, tx_context::sender(ctx)); // Borrowing mutable reference to the account
        assert!(coin::value(&account.current_balance) >= amount, INSUFFICIENT_BALANCE); // Asserting if sufficient balance is available
        let transaction = Transaction { // Creating a withdrawal transaction
            transaction_type: string::utf8(b"withdraw"),
            amount: amount,
            to: none(),
            from: none()
        };
        vector::push_back(&mut account.transactions, transaction); // Recording the transaction
        account.updated_date = clock::timestamp_ms(clock); // Updating the account's updated date
        let transfer_coin = coin::split(&mut account.current_balance, amount, ctx); // Splitting coins for withdrawal
        transfer::public_transfer(transfer_coin, tx_context::sender(ctx)); // Performing the withdrawal
    }

    // Record a transfer transaction
    public fun record_transfer<COIN>(
        tracker: &mut TransactionTracker<COIN>,
        clock: &Clock,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(table::contains<address, Account<COIN>>(&tracker.accounts, tx_context::sender(ctx)), ACCOUNT_NOT_FOUND); // Asserting if the sender's account exists
        assert!(table::contains<address, Account<COIN>>(&tracker.accounts, recipient), INVALID_INDEX); // Asserting if the recipient's account exists
        assert!(tx_context::sender(ctx) != recipient, INVALID_INDEX); // Asserting if sender and recipient are different
        let sender_account = table::borrow_mut<address, Account<COIN>>(&mut tracker.accounts, tx_context::sender(ctx)); // Borrowing mutable reference to sender's account
        assert!(coin::value(&sender_account.current_balance) >= amount, INSUFFICIENT_BALANCE); // Asserting if sufficient balance is available
        sender_account.updated_date = clock::timestamp_ms(clock); // Updating the sender's account's updated date
        let transaction = Transaction { // Creating a transfer transaction
            transaction_type: string::utf8(b"transfer"),
            amount: amount,
            to: some(recipient),
            from: some(tx_context::sender(ctx))
        };
        vector::push_back(&mut sender_account.transactions, *&transaction); // Recording the transaction for the sender
        let transfer_coin = coin::split(&mut sender_account.current_balance, amount, ctx); // Splitting coins for transfer
        let recipient_account = table::borrow_mut<address, Account<COIN>>(&mut tracker.accounts, recipient); // Borrowing mutable reference to recipient's account
        recipient_account.updated_date = clock::timestamp_ms(clock); // Updating the recipient's account's updated date
        vector::push_back(&mut recipient_account.transactions, transaction); // Recording the transaction for the recipient
        coin::join(&mut recipient_account.current_balance, transfer_coin); // Updating the recipient's account balance
    }


    // Get the creation date of the sender's account
    public fun account_create_date<COIN>(self: &TransactionTracker<COIN>, ctx: &mut TxContext): u64 {
        assert!(table::contains<address, Account<COIN>>(&self.accounts, tx_context::sender(ctx)), ACCOUNT_NOT_FOUND); // Asserting if the sender's account exists
        let account = table::borrow<address, Account<COIN>>(&self.accounts, tx_context::sender(ctx)); // Borrowing reference to the sender's account
        account.create_date // Returning the creation date
    }

    // Get the last updated date of the sender's account
    public fun account_updated_date<COIN>(self: &TransactionTracker<COIN>, ctx: &mut TxContext): u64 {
        assert!(table::contains<address, Account<COIN>>(&self.accounts, tx_context::sender(ctx)), ACCOUNT_NOT_FOUND); // Asserting if the sender's account exists
        let account = table::borrow<address, Account<COIN>>(&self.accounts, tx_context::sender(ctx)); // Borrowing reference to the sender's account
        account.updated_date // Returning the last updated date
    }

    // Get the current balance of the sender's account
    public fun account_balance<COIN>(self: &TransactionTracker<COIN>, ctx: &mut TxContext): u64 {
        assert!(table::contains<address, Account<COIN>>(&self.accounts, tx_context::sender(ctx)), ACCOUNT_NOT_FOUND); // Asserting if the sender's account exists
        let account = table::borrow<address, Account<COIN>>(&self.accounts, tx_context::sender(ctx)); // Borrowing reference to the sender's account
        coin::value(&account.current_balance) // Returning the current balance
    }

    // Get the number of accounts in the tracker
    public fun tracker_accounts_length<COIN>(self: &TransactionTracker<COIN>): u64 {
        table::length(&self.accounts) // Returning the number of accounts in the tracker
    }

    // View a specific transaction of the sender's account
    public fun view_account_transaction<COIN>(tracker: &TransactionTracker<COIN>, index: u64, ctx: &mut TxContext): (String, u64, Option<address>, Option<address>) {
        assert!(table::contains<address, Account<COIN>>(&tracker.accounts, tx_context::sender(ctx)), ACCOUNT_NOT_FOUND); // Asserting if the sender's account exists
        let account = table::borrow<address, Account<COIN>>(&tracker.accounts, tx_context::sender(ctx)); // Borrowing reference to the sender's account
        assert!(index < vector::length(&account.transactions), INVALID_OPERATION); // Asserting if the index is within bounds
        let transaction = vector::borrow(&account.transactions, index); // Borrowing the transaction at the specified index
        (transaction.transaction_type, transaction.amount, transaction.to, transaction.from) // Returning transaction details
    }

     // View a specific transaction of any account
    public fun view_transaction<COIN>(tracker: &TransactionTracker<COIN>, account_address: address, index: u64): Option<Transaction> {
            assert!(table::contains<address, Account<COIN>>(&tracker.accounts, account_address), ACCOUNT_NOT_FOUND); // Asserting if the account exists
            let account = table::borrow<address, Account<COIN>>(&tracker.accounts, account_address); // Borrowing reference to the account
            assert!(index < vector::length(&account.transactions), INVALID_OPERATION); // Asserting if the index is within bounds
            let transaction = vector::borrow(&account.transactions, index); // Borrowing the transaction at the specified index
            
            // Wrap data in TransactionInfo struct
            some(Transaction {
                transaction_type: transaction.transaction_type,
                amount: transaction.amount,
                to: transaction.to,
                from: transaction.from,
            })
    }

     // Get the balance of any account
    public fun get_account_balance<COIN>(tracker: &TransactionTracker<COIN>, account_address: address): Option<u64> {
        assert!(table::contains<address, Account<COIN>>(&tracker.accounts, account_address), ACCOUNT_NOT_FOUND); // Asserting if the account exists
        let account = table::borrow<address, Account<COIN>>(&tracker.accounts, account_address); // Borrowing reference to the account
        some(coin::value(&account.current_balance)) // Returning the current balance
    }

    //  Retrieves the total number of transactions associated with a specific account.
    public fun get_account_transactions_length<COIN>(
        tracker: &TransactionTracker<COIN>,
        account_address: address
        ): u64 {
        assert!(table::contains<address, Account<COIN>>(&tracker.accounts, account_address), ACCOUNT_NOT_FOUND); // Asserting if the account exists
        let account = table::borrow<address, Account<COIN>>(&tracker.accounts, account_address); // Borrowing reference to the account
        vector::length(&account.transactions)
    }

    public fun search_transactions_by_type<COIN>(
        tracker: &TransactionTracker<COIN>,
        account_address: address,
        transaction_type: String,
        ctx: &mut TxContext
        ): Option<vector<TransactionInfo>> {
        assert!(table::contains<address, Account<COIN>>(&tracker.accounts, account_address), ENoAccount); // Asserting if the account exists
        let account = table::borrow<address, Account<COIN>>(&tracker.accounts, account_address); // Borrowing reference to the account
        let matching_transactions: vector<TransactionInfo> = vector::empty();
        let i = 0;
        while (i < vector::length(&account.transactions)) {
            let transaction = vector::borrow(&account.transactions, i);
            if (transaction.transaction_type == transaction_type) {
            vector::push_back(&mut matching_transactions, TransactionInfo {
                transaction_type: transaction.transaction_type.clone(), // Clone to avoid ownership issues
                amount: transaction.amount,
                to: transaction.to,
                from: transaction.from,
            });
        };
        i += 1; 
    }
    if (vector::is_empty(&matching_transactions)) {
        none()
    } else {
        some(matching_transactions)
    }
}


}