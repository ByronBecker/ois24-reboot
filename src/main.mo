import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Result "mo:base/Result";

shared ({ caller = creator }) actor class UserCanister() = this {

    stable let owner : Principal = creator;
    stable var _isDead : Bool = false;
    stable var latestPingTime : Time.Time = Time.now();
    // let survivalLength = 24 * 60 * 60 * 1_000_000_000; // One day
    let survivalLength = 10 * 1_000_000_000; // Ten seconds

    public shared ({ caller }) func feed() : async Result.Result<(), { #isDead; #notAuthorized }> {
        if (caller != owner) {
            return #err(#notAuthorized);
        };
        let isDead = calculateOrGetIsDead();
        if (isDead) {
            return #err(#isDead);
        };
        latestPingTime := Time.now();
        #ok;
    };

    public query func isAlive() : async Bool {
        let isDead = calculateOrGetIsDead();
        return not isDead;
    };

    public shared ({ caller }) func resurrect() : async Result.Result<(), { #notDead; #notAuthorized }> {
        if (caller != owner) {
            return #err(#notAuthorized);
        };
        let isDead = calculateOrGetIsDead();
        if (not isDead) {
            return #err(#notDead);
        };
        _isDead := false;
        latestPingTime := Time.now();
        #ok;
    };

    private func calculateOrGetIsDead() : Bool {
        if (_isDead) {
            return true;
        };
        // Check to see if it should be dead
        let pastExpiration = (Time.now() - latestPingTime) > survivalLength;
        if (pastExpiration) {
            _isDead := true;
        };
        return _isDead;
    };

};
