module multicurrency_account::multicurrency_account;

use std::type_name::{Self, TypeName};
use sui::bag::{Self, Bag};
use sui::balance::{Self, Balance};
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};

//=== Structs ===

public struct MulticurrencyAccount has store {
    authorized_currencies: VecSet<TypeName>,
    balances: Bag,
    summary: VecMap<TypeName, u64>,
}

//=== Constants ===

const MAX_CURRENCY_COUNT: u64 = 500;

//=== Errors ===

const EMaxCurrencyCountReached: u64 = 0;
const ENotAuthorizedCurrency: u64 = 1;

//=== Public Functions ===

public fun new(ctx: &mut TxContext): MulticurrencyAccount {
    MulticurrencyAccount {
        authorized_currencies: vec_set::empty(),
        balances: bag::new(ctx),
        summary: vec_map::empty(),
    }
}

public fun deposit<Currency>(self: &mut MulticurrencyAccount, deposit_balance: Balance<Currency>) {
    self.assert_is_authorized_currency<Currency>();
    if (!self.summary.contains(&type_name::get<Currency>())) {
        self.initialize_balance<Currency>();
    };
    self.currency_balance_mut<Currency>().join(deposit_balance);
    self.update_summary_value<Currency>();
}

public fun withdraw<Currency>(self: &mut MulticurrencyAccount, amount: u64): Balance<Currency> {
    let currency_balance = self.currency_balance_mut<Currency>();
    let withdraw_balance = currency_balance.split(amount);
    self.update_summary_value<Currency>();
    withdraw_balance
}

public fun withdraw_all<Currency>(self: &mut MulticurrencyAccount): Balance<Currency> {
    let currency_balance = self.currency_balance_mut<Currency>();
    let withdraw_balance = currency_balance.withdraw_all();
    self.update_summary_value<Currency>();
    withdraw_balance
}

public fun close_balance<Currency>(self: &mut MulticurrencyAccount): Balance<Currency> {
    let currency_type = type_name::get<Currency>();
    self.summary.remove(&currency_type);
    self.balances.remove<TypeName, Balance<Currency>>(currency_type)
}

//=== Public View Functions ===

public fun currency_balance<Currency>(self: &MulticurrencyAccount): &Balance<Currency> {
    self.balances.borrow<TypeName, Balance<Currency>>(type_name::get<Currency>())
}

public fun summary(self: &MulticurrencyAccount): &VecMap<TypeName, u64> {
    &self.summary
}

//=== Private Functions ===

fun currency_balance_mut<Currency>(self: &mut MulticurrencyAccount): &mut Balance<Currency> {
    self.balances.borrow_mut<TypeName, Balance<Currency>>(type_name::get<Currency>())
}

fun initialize_balance<Currency>(self: &mut MulticurrencyAccount) {
    assert!(self.authorized_currencies.size() < MAX_CURRENCY_COUNT, EMaxCurrencyCountReached);
    self.balances.add(type_name::get<Currency>(), balance::zero<Currency>());
    self.summary.insert(type_name::get<Currency>(), 0);
}

fun update_summary_value<Currency>(self: &mut MulticurrencyAccount) {
    let updated_value = self.currency_balance<Currency>().value();
    let summary_value = self.summary.get_mut(&type_name::get<Currency>());
    *summary_value = updated_value;
}

//=== Assertions ===

fun assert_is_authorized_currency<Currency>(self: &MulticurrencyAccount) {
    assert!(
        self.authorized_currencies.contains(&type_name::get<Currency>()),
        ENotAuthorizedCurrency,
    );
}
