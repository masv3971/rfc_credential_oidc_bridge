---
title: "Credential Presentation to OIDC Claims Bridge"
abbrev: "Credential to OIDC Bridge"
category: info

docname: draft-svensson-credential-oidc-bridge-latest
submissiontype: IETF
number:
date:
consensus: true
v: 3
keyword:
 - verifiable credentials
 - OpenID Connect
 - OpenID4VP
 - digital credentials
 - OIDC bridge

author:
 -
    fullname: Magnus Svensson
    organization: SUNET
    email: masv@sunet.se
 -
    fullname: Leif Johansson
    organization: Siros Foundation
    email: leifj@siros.org
 -
    fullname: Joel Rangsmo
    organization: Siros Foundation
    email: joel@siros.org

normative:
  RFC2119:
  RFC8174:
  RFC8259:
  OpenID.Core:
    title: "OpenID Connect Core 1.0"
    author:
      - name: N. Sakimura
      - name: J. Bradley
      - name: M. Jones
      - name: B. de Medeiros
      - name: C. Mortimore
    date: November 2014
    target: https://openid.net/specs/openid-connect-core-1_0.html
  OpenID.Discovery:
    title: "OpenID Connect Discovery 1.0"
    author:
      - name: N. Sakimura
      - name: J. Bradley
      - name: M. Jones
      - name: E. Jay
    date: November 2014
    target: https://openid.net/specs/openid-connect-discovery-1_0.html
  OpenID4VP:
    title: "OpenID for Verifiable Presentations (OpenID4VP) 1.0"
    author:
      - name: O. Terbu
      - name: T. Lodderstedt
      - name: K. Yasuda
      - name: T. Looker
    date: 2024
    target: https://openid.net/specs/openid-4-verifiable-presentations-1_0.html

informative:
  RFC7519:
  RFC7942:
  SD-JWT.VC:
    title: "SD-JWT-based Verifiable Credentials (SD-JWT VC)"
    author:
      - name: O. Terbu
      - name: D. Fett
    date: 2024
    target: https://www.ietf.org/archive/id/draft-ietf-oauth-sd-jwt-vc-05.html
  ISO.18013-5:
    title: "Personal identification — ISO-compliant driving licence — Part 5: Mobile driving licence (mDL) application"
    author:
      - org: ISO/IEC
    date: 2021
    target: https://www.iso.org/standard/69084.html

...

--- abstract

This document defines a mechanism for conveying digital credential
claims via OpenID Connect (OIDC).  It specifies how an OpenID
Provider (OP) that collects credentials from a wallet can expose
those claims to Relying Parties as standard OIDC claims, enabling
existing OIDC deployments to consume digital credentials without
implementing any wallet-facing presentation protocol.


--- middle

# Introduction

Digital credential wallets can present verified claims to verifiers
using protocols such as OpenID for Verifiable Presentations
(OpenID4VP) {{OpenID4VP}} or DIDComm.  However, many existing services
rely on OpenID Connect (OIDC) {{OpenID.Core}} for authentication and
attribute retrieval, and implementing a wallet-facing presentation
protocol represents a significant barrier for these Relying Parties.

This document specifies how an OP, acting as a bridge, can collect
credentials from a wallet using any suitable presentation protocol
and expose the resulting claims in standard OIDC ID Tokens and
UserInfo responses.  The Relying Party interacts with a normal OIDC
flow and receives credential data in the "presented_credentials"
claim without needing any knowledge of the underlying presentation
protocol.

This specification is intended to complement, not compete with, work
produced by the OpenID Foundation.  Implementers are encouraged to
follow developments in the OpenID Foundation's Digital Credentials
Protocols working group.

# Architecture Overview

The following diagram illustrates the high-level interaction between
the participants:

~~~ ascii-art
+--------+                +------------------+              +----------+
|        | 1. OIDC AuthN  |        OP        | 2. Present  |          |
|   RP   | -------------> |     (Bridge)     | ----------> |  Wallet  |
|        |                |                  | <---------- |          |
|        |                |                  | 3. Response |          |
|        |                |                  |             +----------+
|        |                | 4. Verify &      |
|        | 5. ID Token    |    extract claims|
|        | <------------- |                  |
+--------+                +------------------+
~~~

The presentation protocol (step 2-3) is out of scope.
The OP may use OpenID4VP, DIDComm, or any other mechanism.

Flow:

1. RP sends OIDC AuthN Request to OP (credential scopes).
2. OP requests credential presentation from wallet.
3. Wallet responds with disclosed credentials.
4. OP verifies credentials and extracts claims.
5. OP returns ID Token/UserInfo with presented_credentials.

# Terminology

{::boilerplate bcp14-tagged}

# OP (Verifier/Bridge) Requirements

## The presented_credentials Claim

The following is a non-normative example of an OIDC ID Token
containing the "presented_credentials" claim with a credential set
containing two credentials:

~~~ json
{
  "iss": "https://issuer.example.org",
  "sub": "user@example.org",
  "iat": 1722772800,
  "exp": 1722859200,
  "presented_credentials": [
    {
      "ehic": [
        {
          "format": "vc+sd-jwt",
          "vct": "https://credentials.example.org/ehic",
          "claims": {
            "name": "John Doe",
            "dob": "1990-01-01",
            "ehic_number": "1234567890"
          }
        }
      ],
      "pda1": [
        {
          "format": "vc+sd-jwt",
          "vct": "https://credentials.example.org/pda1",
          "claims": {
            "name": "John Doe",
            "dob": "1990-01-01",
            "pda1_number": "0987654321"
          }
        }
      ]
    }
  ]
}
~~~

### The presented_credentials Array

The "presented_credentials" claim is a top-level JSON array included
in the OIDC ID Token or UserInfo response.  It contains credential
data obtained via a credential presentation flow (e.g., OpenID4VP,
DIDComm), re-packaged for consumption by OIDC Relying Parties.

The array contains one or more Credential Set objects.  Each
Credential Set is a JSON object where each key is a scope value
corresponding to a credential type and each value is a JSON array of
Credential Entry objects as defined in {{credential-entry-object}}.

Within a Credential Set:

*  Each key MUST be unique.

*  Each value (array) MUST contain at least one Credential Entry.
   Multiple entries indicate the wallet presented more than one
   credential of that type.

The outer array MUST contain at least one Credential Set.  In most
deployments a single set is returned; multiple sets are possible when
the RP requested alternatives (see {{requesting-credential-claims}}).

Additional members within a Credential Set MAY be present.
Implementations that do not recognise additional members MUST ignore
them.

### Credential Entry Object {#credential-entry-object}

Each Credential Entry object represents a single credential presented
during the presentation flow.  It MUST contain the following member:

claims
: A JSON object {{RFC8259}} containing the disclosed claims from the
  credential.  Each key is a claim name and each value is the claim
  value.  Claim names are determined by the credential type and MUST
  be strings.  Claim values MAY be any valid JSON type.

A Credential Entry object MAY contain the following additional
members:

format
: A string indicating the original credential format (e.g., "vc+sd-
  jwt", "mso_mdoc").  If omitted, the format is unspecified.

vct
: A string containing the Verifiable Credential Type identifier, as
  defined in the credential's metadata.

Additional members MAY be present.  Implementations that do not
recognise additional members MUST ignore them.

## Discovery

An OP that supports this bridge mechanism MUST include
"presented_credentials" in the "claims_supported" list in its OpenID
Connect Discovery {{OpenID.Discovery}} metadata document.

The OP SHOULD also advertise the credential types it can collect by
listing the corresponding scopes in the "scopes_supported" discovery
metadata field (e.g., "ehic", "pda1").

The OP MAY additionally include a "presented_credentials_supported"
member in its discovery metadata.  The value is a JSON array of
objects, each containing at minimum a "scope" string and a "vct"
string, providing RPs with a machine-readable mapping between scopes
and credential types.

## Authentication Flow

When the OP receives an OIDC Authentication Request that includes a
request for credentials (via the "requested_credentials" claims
parameter or a registered scope), it MUST:

1.  Initiate a credential presentation request to the user's wallet
    for the requested credential types, using the presentation
    protocol supported by the deployment.

2.  Verify the presented credentials according to the applicable
    trust framework.

3.  Extract the disclosed claims from each verified credential.

4.  Construct the "presented_credentials" object as defined in
    {{the-presented_credentials-array}}.

5.  Include the "presented_credentials" claim in the ID Token, the
    UserInfo response, or both, depending on the OP's policy and the
    size considerations described in {{claim-set-size-limits}}.

Common presentation protocols include OpenID4VP {{OpenID4VP}} and
DIDComm Present Proof.  The choice of protocol is a deployment
decision and does not affect the "presented_credentials" format
returned to the RP.

## Credential Mapping

The OP MUST use the scope value as the key within the "credentials"
object.  For example, if the RP requested scope "ehic", the resulting
entry MUST be keyed as "ehic".  This ensures a predictable, stable
mapping between the RP's request and the response.

The OP MUST NOT include claims that were not disclosed by the wallet.
The OP MUST NOT modify claim values during the mapping.

The OP is responsible for translating the RP's OIDC-level request
(scopes, claims parameter) into a protocol-specific credential query
directed at the wallet.  For example, when using OpenID4VP the OP
would construct a DCQL (Digital Credentials Query Language) query
matching the requested credential types; when using DIDComm the OP
would build a Present Proof request.  This translation is deployment-
specific and outside the scope of this specification.  The OP MUST
document the mapping between OIDC scopes and the credential types
they resolve to, either in its discovery metadata or in out-of-band
documentation.

The OIDC request model (scopes and the "claims" parameter) is
intentionally simpler than the query languages available in
presentation protocols (e.g., DCQL in OpenID4VP).  This means that
certain constraints expressible in a presentation query — such as
issuer restrictions, issuance date filters, or compound field
requirements — cannot be communicated by the RP.  The OP MUST apply
its own policy to resolve these edge cases (for example, by selecting
the most recent matching credential or by restricting accepted
issuers via configuration).  The OP SHOULD document any such policies
so that RPs can anticipate the resulting behaviour.

The structure of the "presented_credentials" claim MUST be
independent of the credential presentation protocol used between the
OP and the wallet.  Whether the OP collected credentials via
OpenID4VP, DIDComm, or any other mechanism, the resulting claim
format MUST conform to this specification.  The RP MUST NOT need to
be aware of which presentation protocol was used.

# RP (Relying Party) Requirements

## Requesting Credential Claims {#requesting-credential-claims}

An RP that wishes to receive credential data via this bridge MUST
include the appropriate credential type scopes in the OIDC
Authentication Request.  Each scope corresponds to a credential type
(e.g., "ehic", "pda1").  The presence of any credential type scope
signals to the OP that the "requested_credentials" claim parameter
applies.

The requested scopes directly correlate to the keys in credential
sets returned by the OP.  For example, if the RP requests scopes
"ehic" and "pda1", the OP will return a credential set containing
"ehic" and "pda1" entries.

The RP MAY additionally use the "claims" request parameter to specify
which individual claims within a credential type are desired,
enabling selective disclosure.

The RP MAY use the "credential_sets" structure within the
"requested_credentials" claims request parameter to express
combinatorial logic over credential types:

*  *AND (within a set):* Credentials listed in the same credential
   set with "essential": true are all required.  The OP MUST fail the
   authentication if any essential credential in the set cannot be
   obtained.

*  *OR (between sets):* Multiple credential sets represent
   alternatives.  The OP MUST attempt to satisfy the sets in order
   and use the first set that can be fully satisfied.  Only one
   credential set is returned in the response.

The following is a non-normative example requesting PID AND EHIC
together (both are required):

~~~ json
{
  "id_token": {
    "requested_credentials": {
      "credential_sets": [
        {
          "pid": { "essential": true, "claims": ["name"] },
          "ehic": { "essential": true, "claims": ["ehic_number"] }
        }
      ]
    }
  }
}
~~~

The following is a non-normative example requesting PID OR EHIC
(either one satisfies the RP).  The OP tries the first set; if the
wallet cannot provide a PID, it falls back to the second set:

~~~ json
{
  "id_token": {
    "requested_credentials": {
      "credential_sets": [
        {
          "pid": { "essential": true, "claims": ["name"] }
        },
        {
          "ehic": { "essential": true, "claims": ["ehic_number"] }
        }
      ]
    }
  }
}
~~~

The following is a non-normative example requesting PID (required)
with EHIC as optional (nice-to-have):

~~~ json
{
  "id_token": {
    "requested_credentials": {
      "credential_sets": [
        {
          "pid": { "essential": true, "claims": ["name"] },
          "ehic": { "essential": false, "claims": ["ehic_number"] }
        }
      ]
    }
  }
}
~~~

If any credential marked essential is missing from the wallet's
response and no alternative set can be satisfied, the OP MUST return
an OIDC error response (e.g., "access_denied") rather than a partial
credential set.

If the wallet presents multiple credentials of the same type (e.g.,
two EHICs for different family members), the OP returns all of them
in the array.  The RP is responsible for selecting the appropriate
credential by inspecting the returned claims (for example, matching
on name or date of birth against the authenticated user's identity).

## Consuming Credential Claims

The "presented_credentials" claim structure is defined in
{{the-presented_credentials-claim}}.  The RP MUST parse the claim according to that
definition.  Specifically, the RP MUST:

1.  Check for the presence of the "presented_credentials" claim.  If
    the claim was requested as essential and is absent, the RP SHOULD
    treat the authentication as failed.

2.  Parse the "credentials" object and extract the entries relevant
    to its use case.

3.  Validate that the expected claims are present in each Credential
    Entry's "claims" object.

The RP MUST NOT assume that all requested scopes will be present in
the response; the user may have declined to present certain
credentials.  The RP MUST ignore unrecognised credential keys and
unrecognised members within Credential Entry objects.

## Trust Model

The RP places trust in the OP to have correctly verified the
presented credentials.  The RP does not interact with the wallet or
credential issuer directly.  The trust relationship between the RP
and the OP is established through standard OIDC mechanisms (client
registration, token validation, TLS).

# Limitations and Considerations

## Claim Set Size Limits {#claim-set-size-limits}

OIDC ID Tokens are typically passed as JWTs {{RFC7519}} in HTTP headers
or URL fragments, which impose practical size limits.  Browser URL
length limits are commonly around 2048 bytes, and many HTTP servers
reject headers exceeding 8192 bytes.  When multiple credentials with
many disclosed claims are included in the "presented_credentials"
object, the resulting token may exceed these limits.

Implementations SHOULD consider the following mitigations:

*  Return credential claims via the UserInfo endpoint rather than
   embedding them directly in the ID Token.

*  Limit the number of disclosed claims to those requested by the
   Relying Party via the OIDC "claims" parameter.

*  Use token introspection or reference tokens where supported by the
   deployment.

## Error Handling

The OP MUST handle the following failure scenarios gracefully:

Wallet rejection
: The user declines to present credentials.  The OP MAY either omit
  the "presented_credentials" claim entirely or return an OIDC error
  response (e.g., "access_denied") depending on whether the
  credential presentation was essential to the authentication.

Wallet timeout
: The wallet does not respond within a reasonable time.  The OP
  SHOULD treat this as equivalent to a rejection.

Invalid credentials
: The wallet presents credentials that fail verification (expired,
  revoked, untrusted issuer).  The OP MUST NOT include unverified
  credential claims in the "presented_credentials" object.  The OP
  MAY proceed without those credentials or fail the authentication.

Partial presentation
: The wallet presents only a subset of the requested credentials.
  The OP MUST include only the successfully verified credentials and
  MUST NOT fabricate entries for missing credentials.

## Scope Mapping

An OP MAY define custom OIDC scopes that map to specific credential
presentation requests.  For example, the scope "ehic" might trigger a
request for an EHIC credential with a predefined set of claims.

When using scope-based mapping, the OP SHOULD document the mapping
between scopes and credential types in its discovery metadata or out-
of-band documentation.  The OP MUST ensure that the scope semantics
are stable and do not change unexpectedly for registered RPs.

## Scope of This Specification

This specification defines the data format of the
"presented_credentials" claim, the mechanism for requesting and
returning credential claims via OIDC, and the responsibilities of the
OP and RP in that exchange.  The following aspects are explicitly out
of scope:

*  *Credential validation policy.* This specification does not define
   which issuers to trust, which revocation mechanisms to check, or
   what trust frameworks to apply.  These decisions are deployment-
   specific and determined by the OP operator.

*  *Business logic and authorization decisions.* How the RP
   interprets the received claims — for example, whether an EHIC
   credential grants access to a healthcare service, or whether a
   PDA1 is sufficient for a given transaction — is entirely the RP's
   responsibility and outside this specification.

*  *Credential issuance.* This specification deals only with
   presentation of existing credentials, not with the issuance of new
   credentials (which is covered by OpenID4VCI).

*  *Wallet implementation.* The interaction between the OP and the
   wallet uses a presentation protocol such as OpenID4VP or DIDComm.
   This specification does not mandate a specific protocol and does
   not impose additional requirements on wallet implementations.

*  *User consent and identity matching.* How the OP associates a
   credential presentation with an OIDC subject identifier, and how
   user consent is obtained, are implementation details left to the
   OP.

In summary, this specification provides the plumbing for transporting
verified credential claims through OIDC.  Everything above that layer
— trust decisions, access control, and business rules — is the domain
of the deploying parties.

# Implementation Status

This section records the status of known implementations of the
protocol defined by this specification at the time of posting of this
Internet-Draft, and is based on a proposal described in {{RFC7942}}.
The description of implementations in this section is intended to
assist the IETF in its decision processes in progressing drafts to
RFCs.

## SUNET Verifiable Credentials Platform

Organization
: SUNET (Swedish University Computer Network)

Implementation
: Open-source verifiable credentials platform including issuer,
  verifier, and wallet components with an API gateway implementing
  the OpenID4VP-to-OIDC bridge described in this document.

Description
: The implementation supports SD-JWT VC {{SD-JWT.VC}} and mdoc
  {{ISO.18013-5}} credential formats, exposes the
  "presented_credentials" claim via both ID Token and UserInfo
  endpoint, and has been deployed in production for European higher-
  education credential use cases (EHIC, PDA1, micro-credentials).

Maturity
: Production

Coverage
: Implements all normative requirements of this specification.

Contact
: masv@sunet.se

Source Code
: https://github.com/SUNET/vc (open source, BSD-2-Clause)

# Security Considerations

## Credential Replay

The OP MUST ensure that credential presentations are bound to the
current authentication session.  The OP SHOULD use nonces in the
OpenID4VP request to prevent replay of previously captured VP Tokens.

The RP MUST validate standard JWT claims ("iat", "exp", "nonce") in
the ID Token to ensure freshness of the "presented_credentials"
claim.

## Token Leakage

ID Tokens containing "presented_credentials" may carry sensitive
personal data (e.g., national ID numbers, health information).
Implementations MUST use TLS for all token transmissions.  The OP
SHOULD prefer delivering credential claims via the UserInfo endpoint
(which uses a back-channel request) rather than embedding them in the
ID Token (which may be exposed in browser history or logs).

## Claim Injection

The OP MUST NOT allow external parties to inject or modify claims
within the "presented_credentials" object.  The OP MUST populate this
claim exclusively from verified credential presentations.  The ID
Token MUST be signed by the OP to protect integrity.

## Privacy Considerations

The bridge architecture introduces the OP as a party that observes
all credential claims presented by the user.  This creates a
correlation point.  Deployments SHOULD consider the following:

*  The OP SHOULD request only the minimum claims necessary to satisfy
   the RP's request (selective disclosure).

*  The OP SHOULD NOT log or persist credential claims beyond what is
   necessary for the authentication session.

*  RPs SHOULD be aware that repeated presentations of the same
   credential claims across sessions may enable correlation by the
   OP.

*  Where possible, deployments SHOULD use pairwise subject
   identifiers to limit cross-RP correlation.

# IANA Considerations

The claim name "presented_credentials" was chosen to be protocol-
agnostic, clearly describing the content (credentials that were
presented) without implying a dependency on any particular
presentation protocol or namespace.

## JSON Web Token Claims Registration

This specification requests registration of the following claim in
the IANA "JSON Web Token Claims" registry:

Claim Name
: presented_credentials

Claim Description
: Digital credential claims obtained via an OpenID4VP presentation,
  structured for consumption by OIDC Relying Parties.

Change Controller
: IETF

Specification Document(s)
: {{the-presented_credentials-array}} of this document

## OpenID Connect Discovery Metadata Registration

This specification requests registration of the following metadata
parameter:

Metadata Name
: presented_credentials_supported

Metadata Description
: A JSON array describing the credential types the OP can collect
  via OpenID4VP and expose as OIDC claims.

Change Controller
: IETF

Specification Document(s)
: {{discovery}} of this document


--- back

# Acknowledgments
{:numbered="false"}

TODO acknowledge.
