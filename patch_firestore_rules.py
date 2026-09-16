python3 - <<'EOF'
path = "firestore.rules"
with open(path) as f:
    content = f.read()

# 1) Add the top-level collection-group match for invites reads.
old1 = """    match /households/{householdId} {
      allow read: if isHouseholdMember(householdId);"""

new1 = """    // ---------------------------------------------------------------
    // Top-level wildcard match for the invites collection-group query
    // (watchPendingInvitesForEmail: collectionGroup('invites').where(
    // 'email', '==', myEmail()).where('status', '==', 'pending')).
    //
    // Firestore does NOT use the nested `households/{id}/invites/{id}`
    // match below for collection-group queries — it only applies to
    // direct/subcollection access where householdId is already known.
    // A collection-group query needs its own recursive-wildcard rule
    // at this top level, or it falls through to the default-deny rule
    // at the bottom of the file no matter how permissive the nested
    // rule is. This was the actual cause of the PERMISSION_DENIED.
    //
    // Kept provable from the query's own filters alone (no extra
    // get() calls), which collection-group rules require.
    // ---------------------------------------------------------------
    match /{path=**}/invites/{inviteId} {
      allow read: if isSignedIn() && resource.data.email == myEmail();
    }

    match /households/{householdId} {
      allow read: if isHouseholdMember(householdId);"""

if old1 not in content:
    print("PATTERN 1 NOT FOUND"); exit(1)
content = content.replace(old1, new1, 1)

# 2) Remove the TEMP DEBUG nested allow-read and tighten allow-create.
old2 = """      match /invites/{email} {
        // Deliberately NOT `isHouseholdMember(householdId) || ...` here.
        // watchPendingInvitesForEmail is a collectionGroup query, and
        // Firestore rejects a query outright if ANY branch of an OR in
        // its read rule needs an extra get() (like isHouseholdMember)
        // that isn't guaranteed by the query's own filters — even when,
        // as here, that branch is never actually needed by any query
        // this app runs. Keep this rule provable from the query alone.
        // TEMP DEBUG — overly permissive, revert after diagnosing the
        // PERMISSION_DENIED on the collection-group invites query.
        allow read: if isSignedIn();
        allow create: if isHouseholdMember(householdId);"""

new2 = """      match /invites/{email} {
        // `read` is handled by the top-level collection-group match
        // above — do NOT re-add `allow read` here, it would be
        // misleading (never evaluated for the collectionGroup query
        // this app actually runs, and redundant for direct access
        // since the wildcard match above already covers that too).
        allow create: if isHouseholdMember(householdId)
          // Guard against the email field / document-ID casing
          // mismatch that could otherwise let an invite silently
          // fail to match myEmail() on read.
          && request.resource.data.email == request.resource.data.email.lower()
          && email == request.resource.data.email;"""

if old2 not in content:
    print("PATTERN 2 NOT FOUND"); exit(1)
content = content.replace(old2, new2, 1)

with open(path, "w") as f:
    f.write(content)
print("Patched (collection-group invites fix applied, TEMP DEBUG reverted).")
EOF
