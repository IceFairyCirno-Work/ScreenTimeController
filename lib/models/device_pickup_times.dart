/// First and last device pickup (unlock) times for a calendar day.
class DevicePickupTimes {
  final DateTime? firstPickup;
  final DateTime? lastPickup;

  const DevicePickupTimes({
    this.firstPickup,
    this.lastPickup,
  });

  static const empty = DevicePickupTimes();

  bool get hasData => firstPickup != null || lastPickup != null;
}
