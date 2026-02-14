#pragma GCC optimize("O3,unroll-loops")
#pragma GCC target("avx2,bmi,bmi2,lzcnt,popcnt")
#include <bits/stdc++.h>
using namespace std;

using ll = long long;
using ld = long double;
using pii = pair<int, int>;
using pll = pair<ll, ll>;
using vi = vector<int>;
using vll = vector<ll>;

const int INF = 1e9;
const ll LINF = 1e18;
const int MOD = 1e9 + 7;

#define FASTIO ios_base::sync_with_stdio(false);cin.tie(NULL);
#define all(x) (x).begin(), (x).end()
#define sz(x) ((int)(x).size())
#define pb push_back
#define eb emplace_back
#define f first
#define s second

template<typename T> bool chmin(T& a, const T& b) {
    if (b < a) { a = b; return true; }
    return false;
}
template<typename T> bool chmax(T& a, const T& b) {
    if (a < b) { a = b; return true; }
    return false;
}

void solve() {
    
}

int main() {
    FASTIO;
    int t = 1;
    cin >> t;
    while (t--) {
        solve();
    }
    return 0;
}
