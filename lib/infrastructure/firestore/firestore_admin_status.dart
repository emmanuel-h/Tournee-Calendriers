import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tournee_calendriers/application/ports/admin_status.dart';
import 'package:tournee_calendriers/application/ports/member_account.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_layout.dart';

/// The [AdminStatus] over Firestore: an admin is a member whose
/// `admins/{uid}` document exists (PLAN §5.12, §6.2). The security rules
/// let any signed-in phone `get` one, never list them.
///
/// The phone's own document is followed with a listener, served from the
/// phone's copy first: once read, the answer is known after an offline
/// restart. Before the phone has an account there is no uid to ask about,
/// so the answer is no until a sign-in gives one ([MemberAccount.signIns]).
final class FirestoreAdminStatus implements AdminStatus {
  const FirestoreAdminStatus(this._db, this._account);

  final FirebaseFirestore _db;
  final MemberAccount _account;

  @override
  Stream<bool> watchIsAdmin() {
    late final StreamController<bool> controller;
    StreamSubscription<MemberId>? signIns;
    StreamSubscription<DocumentSnapshot<Object?>>? admin;

    void follow(MemberId member) {
      admin = FirestoreLayout.admin(_db, member).snapshots().listen(
        (doc) => controller.add(doc.exists),
        onError: controller.addError,
      );
    }

    controller = StreamController<bool>(
      onListen: () {
        if (_account.signedInMember case final member?) {
          follow(member);
          return;
        }
        controller.add(false);
        // At most one sign-in per launch: the first one is enough.
        signIns = _account.signIns.listen((member) {
          unawaited(signIns?.cancel());
          follow(member);
        });
      },
      // A listener that leaves stops both listeners and frees the stream.
      onCancel: () async {
        await signIns?.cancel();
        await admin?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  /// Asks the server, or the phone's copy when offline; no when neither
  /// can tell: « · admin » is only a label.
  @override
  Future<bool> isAdmin(MemberId member) async {
    try {
      return (await FirestoreLayout.admin(_db, member).get()).exists;
    } on FirebaseException {
      return false;
    }
  }
}
