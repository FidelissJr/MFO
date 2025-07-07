#include <assert.h>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <nlohmann/json.hpp>
#include <string>
#include <unordered_map>

#include "bank.hpp"

using json = nlohmann::json;
using namespace std;

enum class Action {
  Init,
  Deposit,
  Withdraw,
  Transfer,
  BuyInvestment,
  SellInvestment,
  Unknown
};

Action stringToAction(const std::string &actionStr) {
  static const std::unordered_map<std::string, Action> actionMap = {
      {"init", Action::Init},
      {"deposit_action", Action::Deposit},
      {"withdraw_action", Action::Withdraw},
      {"transfer_action", Action::Transfer},
      {"buy_investment_action", Action::BuyInvestment},
      {"sell_investment_action", Action::SellInvestment}};

  auto it = actionMap.find(actionStr);
  if (it != actionMap.end()) {
    return it->second;
  } else {
    return Action::Unknown;
  }
}

int int_from_json(json j) {
  string s = j["#bigint"];
  return stoi(s);
}

map<string, int> balances_from_json(json j) {
  map<string, int> m;
  for (auto it : j["#map"]) {
    m[it[0]] = int_from_json(it[1]);
  }
  return m;
}

map<int, Investment> investments_from_json(json j) {
  map<int, Investment> m;
  for (auto it : j["#map"]) {
    m[int_from_json(it[0])] = {.owner = it[1]["owner"],
                               .amount = int_from_json(it[1]["amount"])};
  }
  return m;
}

BankState bank_state_from_json(json state) {
  map<string, int> balances = balances_from_json(state["balances"]);
  map<int, Investment> investments =
      investments_from_json(state["investments"]);
  int next_id = int_from_json(state["next_id"]);
  return {.balances = balances, .investments = investments, .next_id = next_id};
}

void print_bank_state(BankState &bank_state) {
  // Imprime os saldos
  cout << "Balances:" << endl;
  for (auto &balance : bank_state.balances) {
    cout << "  " << balance.first << ": " << balance.second << endl;
  }

  // Imprime os investimentos
  cout << "Investments:" << endl;
  for (auto &investment_entry : bank_state.investments) {
    cout << "  ID " << investment_entry.first << ": { owner: " << investment_entry.second.owner
         << ", amount: " << investment_entry.second.amount << " }" << endl;
  }

  // Imprime o próximo ID
  cout << "Next ID: " << bank_state.next_id << endl;
}

bool are_equal(const BankState &state1, const BankState &state2) {
  // Comparar balances
  if (state1.balances != state2.balances) {
    return false;
  }

  // Comparar investments
  if (state1.investments.size() != state2.investments.size()) {
    return false;
  }
  for (const auto &[id, investment1] : state1.investments) {
    if (state2.investments.find(id) == state2.investments.end()) {
      return false;
    }
    const auto &investment2 = state2.investments.at(id);
    if (investment1.owner != investment2.owner || investment1.amount != investment2.amount) {
      return false;
    }
  }

  // Comparar next_id
  if (state1.next_id != state2.next_id) {
    return false;
  }

  return true;
}

int main() {
  for (int i = 0; i < 5000; i++) {
    cout << "Trace #" << i << endl;
    std::ifstream f("traces/out" + to_string(i) + ".itf.json");
    json data = json::parse(f);

    // Estado inicial: começamos do mesmo estado incial do trace
    BankState bank_state =
        bank_state_from_json(data["states"][0]["bank_state"]);

    auto states = data["states"];
    for (auto state : states) {
      string action = state["mbt::actionTaken"];
      json nondet_picks = state["mbt::nondetPicks"];

      string error = "";

      // Próxima transição
      switch (stringToAction(action)) {
      case Action::Init: {
        cout << "initializing" << endl;
        break;
      }
      case Action::Deposit: {
        string depositor = nondet_picks["depositor"]["value"];
        int amount = int_from_json(nondet_picks["amount"]["value"]);
        cout << "deposit(" << depositor << ", " << amount << ")" << endl;
        error = deposit(bank_state, depositor, amount);
        break;
      }
      case Action::Withdraw: {
        string withdrawer = nondet_picks["withdrawer"]["value"];
        int amount = int_from_json(nondet_picks["amount"]["value"]);
        cout << "withdraw(" << withdrawer << ", " << amount << ")" << endl;
        error = withdraw(bank_state, withdrawer, amount);
        break;
      }
      case Action::Transfer: {
        string sender = nondet_picks["sender"]["value"];
        string receiver = nondet_picks["receiver"]["value"];
        int amount = int_from_json(nondet_picks["amount"]["value"]);
        cout << "transfer(" << sender << ", " << receiver << ", " << amount << ")" << endl;
        error = transfer(bank_state, sender, receiver, amount);
        break;
      }
      case Action::BuyInvestment: {
        string buyer = nondet_picks["buyer"]["value"];
        int amount = int_from_json(nondet_picks["amount"]["value"]);
        cout << "buy_investment(" << buyer << ", " << amount << ")" << endl;
        error = buy_investment(bank_state, buyer, amount);
        break;
      }
      case Action::SellInvestment: {
        string seller = nondet_picks["seller"]["value"];
        int investment_id = int_from_json(nondet_picks["id"]["value"]);
        cout << "sell_investment(" << seller << ", " << investment_id << ")" << endl;
        error = sell_investment(bank_state, seller, investment_id);
        break;
      }
      default: {
        cout << "TODO: fazer a conexão para as outras ações. Ação: " << action
             << endl;
        error = "";
        break;
      }
      }

      BankState expected_bank_state = bank_state_from_json(state["bank_state"]);

      string expected_error = string(state["error"]["tag"]).compare("Some") == 0
                                  ? state["error"]["value"].get<std::string>()
                                  : "";

      cout << "-------------------- Expected --------------------------------"
           << endl;
      print_bank_state(expected_bank_state);
      cout << "Error: " << expected_error
           << endl;
      cout << "-------------------- Actual ----------------------------------"
           << endl;
      print_bank_state(bank_state);
      cout << "Error: " << error
           << endl;
      cout << "--------------------------------------------------------------"
           << endl
           << endl;

      assert(are_equal(bank_state, expected_bank_state));
      assert(error == expected_error);
    }
  }
  return 0;
}