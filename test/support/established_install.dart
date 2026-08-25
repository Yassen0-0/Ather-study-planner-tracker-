import 'package:ather/presentation/providers/app_providers.dart'
    show kLastAccountUidKey;

/// The uid `FakeAuthRepository.signedIn()` signs in as.
///
/// The gate writes [kLastAccountUidKey] after every settled session, so a
/// device that has run the app under this account carries exactly this value.
const String kSignedInTestUid = 'test-uid';

/// Preferences of an **established single-student install**: the signed-in
/// test uid is already the recorded owner, so the backup gate's hand-over
/// check sees the same student coming back and asks nothing.
///
/// Boots that seed local data but no recorded uid describe a *legacy* device
/// (pre-logins data under no account) -- a state the C1 wipe gate now
/// deliberately intercepts with the confirm sheet. Presentation suites that
/// merely parked a curriculum on the phone want the ordinary state instead:
/// pass [more] through for whatever else the screen under test reads.
Map<String, Object> establishedInstallPrefs([
  Map<String, Object> more = const <String, Object>{},
]) =>
    <String, Object>{
      kLastAccountUidKey: kSignedInTestUid,
      ...more,
    };
