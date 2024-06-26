import DateTime "mo:datetime/DateTime";
import Vector "mo:vector";

import { trap } "mo:base/Debug";
import Error "mo:base/Error";
import { abs } "mo:base/Int";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Time "mo:base/Time";
import { recurringTimer } "mo:base/Timer";

shared ({ caller = deployer }) actor class UserCanister() = this {

    stable let owner : Principal = deployer;
    stable let name : Text = "CanScale";
    stable var about: Text = "My name is Byron. I make memes and build infrastructure for the Internet Computer. Current: co-Founder @CycleOps building IC DevOps automation, and co-founder of @MemePartyFun, bringing people together to laugh. Previous: Founder @CanDB, the first horizontally scalable blockchain data store";
    stable var alive: Bool = true;
    stable let nanosPerHour = 60 * 60 * 1_000_000_000;
    stable let nanosPerDay = 24 * nanosPerHour;
    stable var latestPingTime : Time.Time = Time.now();

    stable let pingLog = Vector.new<(Int, Text)>();

    // Update latest ping time every 23 hours (1 hour before 24 so don't miss a day)
    ignore recurringTimer<system>(
      #nanoseconds(nanosPerDay - (1 * nanosPerHour)),
      func _updateLatestPingTime() : async () {
        let now = Time.now();
        if (now - latestPingTime > nanosPerDay) {
          alive := false;
        };
        latestPingTime := Time.now();
      },
    );

    let board = actor ("q3gy3-sqaaa-aaaas-aaajq-cai") : actor {
      reboot_writeDailyCheck : (name : Text, mood : Text) -> async ();
    };

    public query func getOwner() : async Principal {
      return owner;
    };

    public query func getName() : async Text {
      return name;
    };

    public query func aboutMe() : async Text {
      return about;
    };

    // Am I alive?
    public query func isAlive() : async Bool {
      return alive;
    };

    public query func currentFeeling(): async Text {
      _currentFeeling();
    };

    // Am I sleeping?
    // Sleeping between 12am and 9am PST
    public query func isSleeping() : async Bool {
      _isSleeping();
    };

    // Am I coding?
    // Coding between 9am and 12am PST
    public query func isCoding() : async Bool {
      not _isSleeping();
    };

    public query func getLatestPingTime() : async Nat {
      abs(latestPingTime);
    };

    public query ({ caller }) func getPingLog() : async [(Int, Text)] {
      if (caller != owner) trap("Not authorized");
      return Vector.toArray(pingLog);
    };

    public shared ({ caller }) func triggerPing() : async () {
      if (caller != deployer) trap("Not authorized");
      await _updateLatestPingTime();
    };

    public shared ({ caller }) func setAboutMe(newAbout: Text) : async () {
      if (caller != deployer) trap("Not authorized");
      about := newAbout;
    };

    func _isSleeping() : Bool {
      let now = Time.now();
      // subtract 7 hours to get PST
      let nowInPST = now - (7 * nanosPerHour);
      let nowDTInPST = DateTime.fromTime(nowInPST);
      let isoTime = DateTime.toText(nowDTInPST);
      // split on T to get time
      let time = Iter.toArray(Text.split(isoTime, #text("T")));
      if (time.size() != 2) {
        return false;
      };
      let timeStr = time[1];
      let timeParts = Iter.toArray(Text.split(timeStr, #text(":")));
      if (timeParts.size() != 3) {
        return false;
      };
      let hour = timeParts[0];

      return hour < "09";
    };

    func _currentFeeling() : Text {
      if (_isSleeping()) "In dreamland"
      else "In the zone";
    };

    func _updateLatestPingTime() : async () {
      let now = Time.now();
      if (now - latestPingTime > nanosPerDay) {
        alive := false;
      };
      try {
        let feeling = _currentFeeling();
        await board.reboot_writeDailyCheck(name, feeling);
        Vector.add(pingLog, (now, feeling));
      } catch (e) {
        Vector.add(pingLog, (now, "Error: " # Error.message(e)));
        throw e;
      };
      latestPingTime := Time.now();
    };
};
