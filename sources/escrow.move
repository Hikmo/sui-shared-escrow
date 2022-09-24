module tutorial::shared_escrow {
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::option::{Self, Option};

    // Structs

    struct EscrowObject<T: key + store, phantom ExchangeForT: key + store> has key, store {
        id : UID,
        owner: address,
        item: Option<T>,
        exchangeWith: address,
        excangeFor: ID // the id of the object that owner wishes to exchange T for
    }

    // Errors

    const ENotValidObject: u64 = 0;
    const EWrongRecepient: u64 = 1;
    const EItemCancelledOrExchanged: u64 = 2;
    const ENotOwner: u64 = 3;

    public entry fun create<T: key + store, ExchangeForT: key + store>(
        exchangeWith: address,
        excangeFor: ID,
        item: T,
        ctx: &mut TxContext
    ){
        let id = object::new(ctx);
        let owner = tx_context::sender(ctx);
        transfer::share_object(EscrowObject<T, ExchangeForT>{
            id,
            owner,
            item: option::some(item),
            exchangeWith,
            excangeFor,
        });
    }

    public entry fun excange<T: key + store, ExchangeForT: key + store>(escrowObject: &mut EscrowObject<T, ExchangeForT>, 
    itemToExchange: ExchangeForT, ctx: &mut TxContext){
        assert!(object::borrow_id(&mut itemToExchange) == &mut escrowObject.excangeFor, ENotValidObject);
        assert!(escrowObject.exchangeWith == tx_context::sender(ctx), EWrongRecepient);
        assert!(option::is_some(&mut escrowObject.item), EItemCancelledOrExchanged);
        transfer::transfer(option::extract<T>(&mut escrowObject.item), tx_context::sender(ctx));
        transfer::transfer(itemToExchange, escrowObject.owner);
    }

    public entry fun cancelExchange<T: key + store, ExchangeForT: key + store>(
        escrowObject: &mut EscrowObject<T, ExchangeForT>, ctx: &mut TxContext) {
            assert!(tx_context::sender(ctx) == escrowObject.owner, ENotOwner);
            assert!(option::is_some(&mut escrowObject.item), EItemCancelledOrExchanged);
            transfer::transfer(option::extract(&mut escrowObject.item), escrowObject.owner);
    }
}

// TESTING

#[test_only]
module tutorial::shared_escrow_tests {
    use sui::object::{Self, UID, ID};
    use sui::test_scenario::{Self, Scenario};

    use tutorial::shared_escrow::{Self, EscrowObject};

    struct Item has key, store{
        id: UID,
        value: u8,
    }

    const OKAN: address = @0x1;
    const YAMAN: address = @0x2;

    #[test]
    fun test_escrow() {
        let scenario = &mut test_scenario::begin(&OKAN);
        let object_okan = create_item(scenario, OKAN, 20);
        let object_yaman = create_item(scenario, YAMAN, 30);
        let object_yaman_id = object::id<Item>(&object_yaman);
        create_escrow<Item, Item>(scenario, object_okan, OKAN, YAMAN, object_yaman_id);
        test_scenario::next_tx(scenario, &YAMAN);
        let escrow_object_wrapper = test_scenario::take_shared<EscrowObject<Item, Item>>(scenario);
        let escrow_object = test_scenario::borrow_mut<EscrowObject<Item, Item>>(&mut escrow_object_wrapper);
        exchange(scenario, escrow_object, object_yaman);
        test_scenario::return_shared<EscrowObject<Item, Item>>(scenario, escrow_object_wrapper);
    }

    fun create_item(scenario: &mut Scenario, owner: address, value: u8): Item {
        test_scenario::next_tx( scenario, &owner);
        let ctx = test_scenario::ctx(scenario);
        Item {
            id: object::new(ctx),
            value
        }
    }

    fun create_escrow<T: key + store, ExchangeForT: key + store>
        (scenario: &mut Scenario, item: T, owner: address, exchangeWith: address, exchangeFor: ID) {
        test_scenario::next_tx(scenario, &owner);
        let ctx = test_scenario::ctx(scenario);
        shared_escrow::create<T, ExchangeForT>(exchangeWith, exchangeFor, item, ctx);
    }

    fun exchange<T: key + store, ExchangeForT: key + store>
        (scenario: &mut Scenario, escrow_object: &mut EscrowObject<T, ExchangeForT>, itemToExchange: ExchangeForT) {
        let ctx = test_scenario::ctx(scenario);
        shared_escrow::excange<T, ExchangeForT>(escrow_object, itemToExchange, ctx);
    } 

    fun cancel<T: key + store, ExchangeForT: key + store>
        (scenario: Scenario, escrow_object: &mut EscrowObject<T, ExchangeForT>, owner: address){
        test_scenario::next_tx(&mut scenario, &owner);
        let ctx = test_scenario::ctx(&mut scenario);  
        shared_escrow::cancelExchange<T, ExchangeForT>(escrow_object, ctx);     
    }

}