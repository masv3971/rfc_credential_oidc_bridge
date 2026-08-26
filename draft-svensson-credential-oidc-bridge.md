---
title: "Credential Presentation to OIDC Claims Bridge"
abbrev: "Credential to OIDC Bridge"
category: info

docname: draft-svensson-credential-oidc-bridge-latest
submissiontype: IETF
ipr: trust200902
area: sec
workgroup: TBD
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
  RFC7519:
  RFC8126:
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
  SD-JWT.VC:
    title: "SD-JWT-based Verifiable Credentials (SD-JWT VC)"
    author:
      - name: O. Terbu
      - name: D. Fett
    date: 2024
    target: https://www.ietf.org/archive/id/draft-ietf-oauth-sd-jwt-vc-05.html
  ISO.18013-5:
    title: "Personal identification -- ISO-compliant driving licence -- Part 5: Mobile driving licence (mDL) application"
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
flow and receives credential data in the "presented_credential_sets"
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
|        | 1. OIDC AuthN  |                  | 2. Present   |          |
|   RP   | -------------> |    OP (Bridge)   | -----------> |  Wallet  |
|        |                |                  | <----------- |          |
|        |                |                  | 3. Response  |          |
|        |                |                  |              +----------+
|        |                | 4. Verify &      |
|        | 5. ID Token    |    extract claims|
|        | <------------- |                  |
+--------+                +------------------+
~~~

The presentation protocol (steps 2-3) is out of scope for this
specification.  The OP MAY use OpenID4VP, DIDComm, or any other
suitable mechanism.

The steps are:

1.  The RP sends an OIDC Authentication Request to the OP,
    including credential type scopes.

2.  The OP initiates a credential presentation request to the
    user's wallet.

3.  The wallet responds with the disclosed credentials.

4.  The OP verifies the credentials and extracts claims.

5.  The OP returns an ID Token and/or UserInfo response containing
    the "presented_credential_sets" claim.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

The following terms are used throughout this document:

Relying Party (RP)
: An OIDC client that consumes claims from the OP.  In this
  specification, the RP receives credential claims without
  directly interacting with the wallet.

OpenID Provider (OP)
: The authorization server that acts as a bridge between the
  wallet and the RP.  The OP collects credentials from the wallet
  using a presentation protocol and exposes the resulting claims
  via standard OIDC mechanisms.

Wallet
: A user-controlled application that holds digital credentials and
  can present them to a verifier upon request.

Credential Set
: A JSON object within the "presented_credential_sets" array with
  two members: an OPTIONAL "credential_set_id" (a string that
  echoes an RP-supplied DCQL Credential Set id) and a REQUIRED
  "credentials" (an object mapping each credential type scope
  value or DCQL Credential Query id to an array of Credential
  Entry objects).

Credential Entry
: A JSON object representing a single credential presented during
  the presentation flow, containing metadata and disclosed claims.

# Relying Party Requirements

## Requesting Credential Claims {#requesting-credential-claims}

An RP that wishes to receive credential data via this bridge MUST
include credential type scopes in the OIDC Authentication Request
(e.g., `scope=openid ehic pda1`).  This specification defines two
request modes:

*  *Scope-based (REQUIRED to support):* the RP includes only
   credential type scopes.  The OP applies a pre-registered query
   per scope (see {{credential-mapping}}) and returns the claims
   configured for that credential type.  Every OP that implements
   this specification MUST support this mode.

*  *DCQL-based (OPTIONAL):* the RP additionally supplies a
   "dcql_query" member inside the OIDC "claims" request parameter.
   The value is a DCQL query {{OpenID4VP}} constrained to the
   profile defined in {{dcql-based-requests}}.

Deployments operating under trust frameworks that require pre-
registered credential queries (for example, EUDI and the Swiss
Trust Framework) MUST NOT advertise "dcql_query_supported" as
`true`.  An RP that sends a "dcql_query" to such an OP will
receive an "invalid_request" error per {{dcql-based-requests}}.
An RP MUST consult the OP's discovery metadata (see
{{discovery}}) to determine whether the DCQL-based mode is
supported before including a "dcql_query".

Scopes identify which credentials to collect; the "dcql_query"
member, when present, refines how they are collected.  If only
scopes are present, the OP applies its pre-registered mapping for
each scope.

### Scope-Based Requests {#scope-based-requests}

The following is a non-normative example of a scope-based request
(no "claims" parameter).  The RP requests EHIC and PDA1 credentials
using the OP's pre-registered mapping:

~~~ http
GET /authorize?
  response_type=code
  &scope=openid ehic pda1
  &client_id=https://rp.example.org
  &redirect_uri=https://rp.example.org/cb
  &nonce=n-0S6_WzA2Mj HTTP/1.1
~~~

The requested scopes directly correlate to the keys used in the
Credential Set returned by the OP.  For example, if the RP requests
scopes "ehic" and "pda1", the resulting Credential Set contains
"ehic" and "pda1" entries.

In scope-based mode the RP cannot express selective disclosure,
value constraints, or issuer restrictions on a per-request basis;
the OP applies its own policy.  RPs that need such control MAY use
the DCQL-based mode ({{dcql-based-requests}}) where supported by
the OP.

### DCQL-Based Requests {#dcql-based-requests}

An RP MAY supply a "dcql_query" member inside the OIDC "claims"
request parameter as permitted by Section 5.5.1 of {{OpenID.Core}}.
The "dcql_query" value MUST be a DCQL query object as defined in
Section 6 of {{OpenID4VP}}, restricted to the profile defined in
this section.

An OP that supports the DCQL-based mode MUST advertise this in its
discovery metadata via "dcql_query_supported" (see {{discovery}}).
If the OP does not support the DCQL-based mode and the RP supplies
a "dcql_query", the OP MUST return an OIDC error response with
error code "invalid_request".

The "dcql_query" value is a DCQL query object as defined in
Section 6 of {{OpenID4VP}}.  All member definitions, required and
optional fields, and format-specific rules (e.g., for the "meta"
object of `dc+sd-jwt` and `mso_mdoc`) are inherited from that
section and are not restated here.

This profile applies the following additional restrictions:

*  The DCQL "claim_sets" member MAY be used to express claim-
   level alternation within a single Credential Query (for
   example, "family_name OR given_name from this PID").  When
   present, the OP MUST forward "claim_sets" to the wallet
   unchanged and MUST validate after presentation that the
   disclosed claims satisfy at least one of the listed claim-set
   options, per Section 6.4.2 of {{OpenID4VP}}.  A Credential
   Query whose disclosed claims do not satisfy any listed option
   MUST be treated as not satisfying the query.

*  Each Credential Query MUST identify a credential type (via
   "format" and the format-specific type identifier in "meta")
   that matches an entry in "credential_presentations_supported"
   whose scope value is present in the authorization request.
   Otherwise the OP MUST return "invalid_request".

*  Credential Query "id" values are opaque to the OP (per
   Section 6 of {{OpenID4VP}}) and are used only as response
   keys and as references from "credential_sets".

*  When "claims" is omitted, the OP applies the pre-registered
   claim set of the matched entry.

The "credential_sets" member expresses combinatorial logic over
Credential Queries as defined in Section 6.3 of {{OpenID4VP}}.
Each Credential Set entry contains an "options" array listing
alternative AND-groups of Credential Query "id"s, plus an OPTIONAL
"id" and OPTIONAL "required" boolean (default `true`).  If
"credential_sets" is present, the OP MUST evaluate the alternation
per Section 6.3 of {{OpenID4VP}} and return, for each satisfied
Credential Set, one Credential Set object within the
"presented_credential_sets" claim (see {{presented-credential-sets-array}})
whose members are the Credential Queries in the matched AND-group.
The OPTIONAL "id" of the Credential Set entry MAY be echoed by the
OP in the response as the "credential_set_id" member of the
corresponding Credential Set (see {{presented-credential-sets-array}}),
to help the RP identify which alternative was satisfied.

If "credential_sets" is absent, the OP treats all Credential
Queries as required, matching the DCQL default behaviour.

Trusted authority handling:

*  When a Credential Query includes "trusted_authorities", the OP
   MUST only accept a credential for that query if it chains to at
   least one of the listed authorities.  Credentials that do not
   chain to any listed authority MUST be treated as not satisfying
   the query.
*  If "trusted_authorities" is absent, the OP applies its own
   issuer policy.
*  Security requirements for dereferencing external trust list
   references (e.g., "etsi_tl", "openid_federation") are given in
   {{trust-list-fetching}}.

The following is a non-normative example requesting a PID from a
specific pair of trusted authorities using the OpenID Federation
authority type:

~~~ json
{
  "id_token": {
    "dcql_query": {
      "credentials": [
        {
          "id": "pid",
          "format": "dc+sd-jwt",
          "meta": {
            "vct_values": ["urn:eu.europa.ec.eudi:pid:1"]
          },
          "claims": [
            {"path": ["family_name"]},
            {"path": ["given_name"]},
            {"path": ["birth_date"]}
          ],
          "trusted_authorities": [
            {
              "type": "openid_federation",
              "values": [
                "https://pid.example.gov.se",
                "https://pid.example.gov.no"
              ]
            }
          ]
        }
      ]
    }
  }
}
~~~

The following is a non-normative example using an ETSI Trust List
to accept PID and EHIC credentials from any issuer recognised by
the list, without enumerating each issuer individually:

~~~ json
{
  "id_token": {
    "dcql_query": {
      "credentials": [
        {
          "id": "pid",
          "format": "dc+sd-jwt",
          "meta": {"vct_values": ["urn:eu.europa.ec.eudi:pid:1"]},
          "claims": [
            {"path": ["family_name"]},
            {"path": ["birth_date"]}
          ],
          "trusted_authorities": [
            {
              "type": "etsi_tl",
              "values": ["https://trust.eu.example.org/tsl.xml"]
            }
          ]
        },
        {
          "id": "ehic",
          "format": "dc+sd-jwt",
          "meta": {"vct_values": ["urn:eu.europa.ec.eudi:ehic:1"]},
          "claims": [
            {"path": ["ehic_number"]}
          ],
          "trusted_authorities": [
            {
              "type": "etsi_tl",
              "values": ["https://trust.eu.example.org/tsl.xml"]
            }
          ]
        }
      ]
    }
  }
}
~~~

The following is a non-normative example expressing "PID AND EHIC
together":

~~~ json
{
  "id_token": {
    "dcql_query": {
      "credentials": [
        {
          "id": "pid",
          "format": "dc+sd-jwt",
          "meta": {"vct_values": ["urn:eu.europa.ec.eudi:pid:1"]},
          "claims": [{"path": ["family_name"]}]
        },
        {
          "id": "ehic",
          "format": "dc+sd-jwt",
          "meta": {"vct_values": ["urn:eu.europa.ec.eudi:ehic:1"]},
          "claims": [{"path": ["ehic_number"]}]
        }
      ],
      "credential_sets": [
        {
          "id": "pid_and_ehic",
          "options": [["pid", "ehic"]]
        }
      ]
    }
  }
}
~~~

The following is a non-normative example expressing "PID OR EHIC"
using two alternatives.  Only the AND-group that was satisfied
appears in the corresponding Credential Set in the response:

~~~ json
{
  "id_token": {
    "dcql_query": {
      "credentials": [
        {
          "id": "pid",
          "format": "dc+sd-jwt",
          "meta": {"vct_values": ["urn:eu.europa.ec.eudi:pid:1"]},
          "claims": [{"path": ["family_name"]}]
        },
        {
          "id": "ehic",
          "format": "dc+sd-jwt",
          "meta": {"vct_values": ["urn:eu.europa.ec.eudi:ehic:1"]},
          "claims": [{"path": ["ehic_number"]}]
        }
      ],
      "credential_sets": [
        {
          "id": "pid_or_ehic",
          "options": [["pid"], ["ehic"]]
        }
      ]
    }
  }
}
~~~

The following is a non-normative example expressing "PID required,
EHIC nice-to-have" using two Credential Sets, one required and one
optional:

~~~ json
{
  "id_token": {
    "dcql_query": {
      "credentials": [
        {
          "id": "pid",
          "format": "dc+sd-jwt",
          "meta": {"vct_values": ["urn:eu.europa.ec.eudi:pid:1"]},
          "claims": [{"path": ["family_name"]}]
        },
        {
          "id": "ehic",
          "format": "dc+sd-jwt",
          "meta": {"vct_values": ["urn:eu.europa.ec.eudi:ehic:1"]},
          "claims": [{"path": ["ehic_number"]}]
        }
      ],
      "credential_sets": [
        {"id": "pid_required", "options": [["pid"]], "required": true},
        {"id": "ehic_optional", "options": [["ehic"]], "required": false}
      ]
    }
  }
}
~~~

The following is a non-normative example applying a value
constraint on "age_over_18":

~~~ json
{
  "id_token": {
    "dcql_query": {
      "credentials": [
        {
          "id": "pid",
          "format": "dc+sd-jwt",
          "meta": {"vct_values": ["urn:eu.europa.ec.eudi:pid:1"]},
          "claims": [
            {"path": ["family_name"]},
            {"path": ["age_over_18"], "values": [true]}
          ]
        }
      ]
    }
  }
}
~~~

The following is a non-normative example requesting nested claims
from a PID credential:

~~~ json
{
  "id_token": {
    "dcql_query": {
      "credentials": [
        {
          "id": "pid",
          "format": "dc+sd-jwt",
          "meta": {"vct_values": ["urn:eu.europa.ec.eudi:pid:1"]},
          "claims": [
            {"path": ["family_name"]},
            {"path": ["address", "street_address"]},
            {"path": ["address", "country"], "values": ["SE"]}
          ]
        }
      ]
    }
  }
}
~~~

If the wallet presents multiple credentials matching a single
Credential Query (e.g., two EHICs for different family members),
the OP returns all of them in the corresponding array within the
Credential Set.  The RP is responsible for selecting the
appropriate credential by inspecting the returned claims (for
example, matching on name or date of birth against the
authenticated user's identity).

## Consuming Credential Claims

The "presented_credential_sets" claim structure is defined in
{{presented-credential-sets-claim}}.  The RP MUST parse the claim according to that
definition.

Credential authenticity, holder binding, revocation status, and
enforcement of any DCQL constraints supplied by the RP are the
responsibility of the OP (see {{trust-model}}); the RP does not
re-verify the credential.  The "verification" object and other
validation-related metadata returned by the OP (see
{{credential-entry-object}}) are informational: the RP MAY use
them as inputs to its own business logic, policy engine, or audit
records.  How the RP uses that metadata is a matter of local
policy and out of scope for this specification, except where
noted for "verification.crit" in {{credential-entry-object}}.

Specifically, the RP MUST:

1.  Check for the presence of the "presented_credential_sets" claim.  If
    the claim was requested as essential and is absent, the RP SHOULD
    treat the authentication as failed.

2.  Parse the "presented_credential_sets" array and extract the
    Credential Set objects relevant to its use case.

3.  Not assume that all requested scopes will be present in the
    response; the user may have declined to present certain
    credentials.

4.  Except for members listed in "verification.crit", ignore
    unrecognised credential keys and unrecognised members within
    Credential Entry objects.

## Trust Model {#trust-model}

The RP places trust in the OP to have correctly verified the
presented credentials.  The RP does not interact with the wallet or
credential issuer directly.  The trust relationship between the RP
and the OP is established through standard OIDC mechanisms (client
registration, token validation, TLS).

## Liability and Accountability

The bridge architecture shifts credential verification responsibility
from the RP to the OP.  This has implications for liability that
deployments MUST consider.

The OP is the sole party that interacts with the wallet and verifies
credential authenticity, revocation status, and holder binding.  The
RP relies entirely on the OP's assertion that the credential claims
are valid.  If the OP incorrectly accepts a forged, expired, or
revoked credential, the RP has no independent means of detecting
this.

Deployments SHOULD establish clear agreements between the OP operator
and RPs that address:

*  The OP's obligations regarding credential verification (e.g.,
   which trust frameworks it enforces, whether it checks revocation).

*  Liability allocation when the OP accepts a credential that turns
   out to be invalid or fraudulent.

*  The OP's obligations to communicate changes to its verification
   policy that may affect RP authorization decisions.

*  Audit and logging requirements that allow after-the-fact review of
   verification decisions.

The "verification" metadata in the Credential Entry
({{credential-entry-object}}) provides a technical mechanism for the OP
to communicate verification details to the RP.  However, the
"verification" object does not constitute a legal guarantee.  RPs
operating in regulated environments (e.g., healthcare, finance)
SHOULD require contractual assurances from the OP in addition to the
technical signals provided by this specification.

# OpenID Provider Requirements

## The presented_credential_sets Claim {#presented-credential-sets-claim}

The following is a non-normative example of an OIDC ID Token
containing the "presented_credential_sets" claim with a credential set
containing two credentials:

~~~ json
{
  "iss": "https://issuer.example.org",
  "sub": "user@example.org",
  "iat": 1722772800,
  "exp": 1722859200,
  "presented_credential_sets": [
    {
      "credential_set_id": "ehic_and_pda1",
      "credentials": {
        "ehic": [
          {
            "type": ["https://credential.example.org/ehic/1.0"],
            "issuer": "https://svs.example.se",
            "valid_from": 1709251200,
            "valid_until": 1740787200,
            "verified_at": 1722772700,
            "verification": {
              "trust_status": "not_checked",
              "holder_binding": "key_binding"
            },
            "claims": {
              "name": "John Doe",
              "dob": "1990-01-01",
              "ehic_number": "1234567890"
            }
          }
        ],
        "pda1": [
          {
            "type": ["https://credential.example.org/pda1/1.0"],
            "issuer": "https://tax.example.se",
            "valid_from": 1709251200,
            "valid_until": 1740787200,
            "verified_at": 1722772700,
            "verification": {
              "trust_status": "not_checked",
              "holder_binding": "key_binding"
            },
            "claims": {
              "name": "John Doe",
              "dob": "1990-01-01",
              "pda1_number": "0987654321",
              "employer": {
                "name": "Example Corp AB",
                "country": "SE"
              }
            }
          }
        ]
      }
    }
  ]
}
~~~

### The presented_credential_sets Array {#presented-credential-sets-array}

The "presented_credential_sets" claim is a top-level JSON array included
in the OIDC ID Token or UserInfo response.  It contains credential
data obtained via a credential presentation flow (e.g., OpenID4VP,
DIDComm), re-packaged for consumption by OIDC Relying Parties.

The array contains one or more Credential Set objects.  Each
Credential Set is a JSON object with the following members:

credential_set_id
: OPTIONAL string.  When the RP used the DCQL-based mode
  ({{dcql-based-requests}}) and supplied a "credential_sets" entry
  with an "id", the OP MAY echo that "id" here to allow the RP to
  identify which entry in its "credential_sets" array was
  satisfied.  The value is chosen by the RP and treated as opaque
  by the OP; for example, an RP that asked for "PID or EHIC" via
  a "credential_sets" entry with `"id": "pid_or_ehic"` receives
  the string "pid_or_ehic" back as "credential_set_id" on the
  corresponding Credential Set in the response.

credentials
: REQUIRED JSON object.  Each key is either a credential type
  scope value (in scope-based mode) or a DCQL Credential Query
  "id" (in DCQL-based mode).  Each value is a JSON array of one
  or more Credential Entry objects as defined in
  {{credential-entry-object}}.  Multiple entries in a single
  array indicate that the wallet presented more than one
  credential of that type.

Within the "credentials" object each key MUST be unique.  No key
inside "credentials" is reserved; scope values and DCQL
Credential Query identifiers are free to use any string.

The outer array MUST contain at least one Credential Set.  In most
deployments a single set is returned; multiple sets are possible
when the RP requested alternatives via "credential_sets" in the
DCQL-based mode (see {{requesting-credential-claims}}).  In that
case the OP MUST return one Credential Set object per satisfied
DCQL Credential Set entry, in the same order as they appeared in
the request.

Additional members within a Credential Set MAY be present.
Implementations that do not recognise additional members MUST
ignore them.

### Credential Entry Object {#credential-entry-object}

Each Credential Entry object represents a single credential
presented during the presentation flow.  It MUST contain the
following members:

type
: A non-empty JSON array of strings identifying the credential
  type.  The array contents are credential-format specific:

  *  For SD-JWT VC credentials the array contains a single element:
     the Verifiable Credential Type (vct).
  *  For ISO mdoc credentials the array contains a single element:
     the docType.
  *  For W3C Verifiable Credentials the array is the credential's
     "type" array, preserving the order in the credential.
  *  For other formats the array contains the type identifier(s)
     that the credential format defines, preserving any ordering
     defined by that format.  Single-value formats produce a
     one-element array.

  The OP MUST set this field based on the presented credential.

claims
: A JSON object {{RFC8259}} containing the disclosed claims from
  the credential.  Each key is a claim name and each value is the
  claim value.  Claim names are determined by the credential type
  and MUST be strings.  Claim values MAY be any valid JSON type.

It MAY contain the following additional members:

issuer
: A string identifying the entity that issued the credential.  For
  SD-JWT VC credentials this is the "iss" claim value, for mdoc
  credentials it is the issuing authority identifier.  The OP
  SHOULD populate this field to allow the RP to make issuer-aware
  authorization decisions.

namespaces
: A JSON object mapping credential-format-specific namespace
  identifiers to per-namespace claim objects.  This member is
  intended for formats that scope claims by namespace, such as
  ISO mdoc, where each key corresponds to an mdoc NameSpace
  identifier and each value is a JSON object of the disclosed
  claims within that namespace.  For mdoc credentials that
  disclose claims from more than one namespace, the OP MUST use
  "namespaces" to preserve the mapping between claims and their
  originating namespace.  When "namespaces" is present for an
  mdoc credential the "claims" member MUST NOT also be present
  at the Credential Entry root.  For credential formats that do
  not use namespaces this member MUST NOT be present.

valid_from
: A NumericDate (as defined in {{RFC7519}}) indicating when the
  credential became valid (i.e., the issuance or activation date).

valid_until
: A NumericDate indicating when the credential expires.  The OP
  MAY include credentials whose "valid_until" is in the past at
  the time of presentation; in that case the OP MUST set the
  "trust_status" member of the "verification" object to "expired"
  (see {{trust-status-registry}}) so that the RP can act on the
  signal.  Whether to accept an expired credential is outside the
  scope of this specification and is governed by deployment
  policy, the applicable trust framework, and any agreements
  between the OP and the RP.

verified_at
: A NumericDate indicating when the OP verified the credential
  during the presentation flow.  This allows the RP to assess the
  freshness of the verification relative to its own requirements.

verification
: OPTIONAL JSON object providing metadata about the verification
  the OP performed on the credential.  Omission of the
  "verification" object is semantically equivalent to a
  "verification" object containing only `"trust_status":
  "not_checked"` (see {{trust-status-registry}}).  When the OP
  includes the object it MUST set "trust_status"; other members
  of "verification" MAY be omitted when the corresponding
  information is unavailable.  This object MAY contain the
  following members:

  holder_binding
  : A string describing the mechanism used to verify that the
    presenter is the legitimate holder of the credential.  Values
    are taken from the "Credential Holder Binding Methods"
    registry defined in {{holder-binding-registry}}.

  trust_status
  : A string describing the OP's assessment of the credential's
    trust status at the time of verification.  Values are taken
    from the "Credential Trust Status Values" registry defined in
    {{trust-status-registry}}.  If the OP did not perform a
    trust-status check, the OP MUST set this member to
    "not_checked" rather than omitting it.  If the OP performed a
    check but the authoritative source returned no conclusive
    answer, the OP MUST set this member to "unknown".

  protected_headers
  : A JSON object echoing selected verified protected-header
    parameters from the underlying credential (e.g., JOSE "alg",
    "kid", "x5c", or COSE protected headers for mdoc).  The OP
    MUST populate this member exclusively from headers that were
    covered by the credential's signature verification and MUST
    NOT include unverified data.  The set of parameters included
    is a deployment decision.

  crit
  : A JSON array of non-empty strings, each naming another member
    of the same "verification" object that the RP MUST understand
    to accept the credential.  Semantics are modelled after the
    "crit" Header Parameter of Section 4.1.11 of RFC 7515.  If the
    RP does not recognise every member listed in "crit", or does
    not understand the semantics assigned to the listed member's
    value, the RP MUST treat the credential as not satisfying the
    request.  Values listed in "crit" MUST also appear as members
    of the "verification" object; the string "crit" itself MUST
    NOT appear in the array.  This mechanism allows the OP to
    ensure that safety-critical signals (e.g., a "trust_status" of
    "suspended") cannot be silently ignored.

    The "crit" list applies to each delivery of
    "presented_credential_sets".  When the same "presented_credential_sets"
    value is delivered via both the ID Token and the UserInfo
    response, the RP MUST re-evaluate "crit" against each copy
    independently; failure to understand a listed critical member
    in a given copy MUST cause the RP to treat that Credential
    Entry as not satisfying the request in that channel.

  Additional members within the "verification" object MAY be
  present.  Unless listed in "crit", implementations that do not
  recognise additional members MUST ignore them.

digest
: OPTIONAL JSON object providing a one-way digest of the source
  credential, enabling RP-side audit and non-repudiation trails
  that tie the flattened claims back to a specific signed
  credential.  When present, it MUST contain the following
  members:

  alg
  : A string identifying the hash algorithm, taken from the IANA
    "Named Information Hash Algorithm Registry".
    Implementations MUST support "sha-256".

  value
  : The base64url-encoded digest, without padding.

  The digest input is credential-format specific.  For SD-JWT VC
  credentials it is the compact serialization of the issuer-
  signed JWT concatenated with all disclosed disclosures
  (excluding any Key Binding JWT).  For ISO mdoc credentials it
  is the encoded Mobile Security Object (MSO).  For W3C
  Verifiable Credentials it is the canonicalised proof value.
  For other formats the input is defined by that format's
  specification.

primary
: OPTIONAL boolean.  When present with the value `true`, this
  member signals that the OP considers this Credential Entry the
  primary source of identity for the enclosing Credential Set,
  and, for example, the input to the OIDC "sub" derivation rules
  in {{sub-derivation}}.  At most one Credential Entry per
  Credential Set MAY carry `"primary": true`.  When omitted, the
  default is `false`.

The following is a non-normative example of a Credential Entry
with nested claims and an extended "verification" object, as might
appear in a PID credential whose trust status the OP wants the RP
to acknowledge:

~~~ json
{
  "type": ["urn:eu.europa.ec.eudi:pid:1"],
  "issuer": "https://pid.example.gov.se",
  "valid_from": 1709251200,
  "valid_until": 1740787200,
  "verified_at": 1722772700,
  "verification": {
    "holder_binding": "key_binding",
    "trust_status": "suspended",
    "protected_headers": {
      "alg": "ES256",
      "kid": "pid-signer-2026"
    },
    "crit": ["trust_status"]
  },
  "claims": {
    "family_name": "Doe",
    "given_name": "John",
    "birth_date": "1990-01-01",
    "address": {
      "street_address": "123 Main St",
      "locality": "Stockholm",
      "postal_code": "11122",
      "country": "SE"
    },
    "age_over_18": true,
    "nationalities": [
      "SE",
      "NO"
    ]
  }
}
~~~

The following is a non-normative example of a Credential Entry for
a W3C Verifiable Credential where "type" is an array:

~~~ json
{
  "type": ["VerifiableCredential", "UniversityDegreeCredential"],
  "issuer": "https://university.example.edu",
  "verified_at": 1722772700,
  "verification": {
    "trust_status": "not_checked",
    "holder_binding": "key_binding"
  },
  "claims": {
    "degree": {
      "type": "BachelorDegree",
      "name": "Bachelor of Science and Arts"
    }
  }
}
~~~

Additional members MAY be present.  Implementations that do not
recognise additional members MUST ignore them.

## Discovery {#discovery}

An OP that supports this bridge mechanism MUST include
"presented_credential_sets" in the "claims_supported" list in its
OpenID Connect Discovery {{OpenID.Discovery}} metadata document.

The OP MUST include a "credential_presentations_supported" member
in its discovery metadata.  This is a JSON object where each key is
a scope value that the RP can use in the authorization request,
and each value is an object describing the credential type
configuration.  Each configuration object MUST contain at minimum:

format
: A string identifying the credential format (e.g., "dc+sd-jwt",
  "mso_mdoc").

type
: A non-empty JSON array of strings identifying the credential
  type, matching the shape of the "type" member of the Credential
  Entry ({{credential-entry-object}}).  For SD-JWT VC and mdoc
  credentials the array MUST contain exactly one element (the vct
  value or the docType respectively).  For W3C Verifiable
  Credentials the array MAY contain multiple elements.

Each configuration object MAY additionally contain:

claims
: OPTIONAL JSON array of DCQL-style claim path arrays (see Section
  6.4 of {{OpenID4VP}}) enumerating the pre-registered claim set
  that the OP returns in scope-based mode for this scope (see
  {{credential-mapping}}).  When present, RPs can rely on the
  listed paths as the complete set of claims returned via the
  scope-based mode; when absent, the returned claim set is out
  of band.

subject_claim
: OPTIONAL JSON array of strings identifying the claim path (as a
  DCQL claim path) whose value the OP SHOULD use as the stable
  identifier input when deriving the OIDC "sub" claim from a
  credential of this type (see {{sub-derivation}}).

The OP uses this metadata to translate the RP's scope request into
the correct credential query (e.g., a DCQL query with the
appropriate "vct_values" or "doctype_value") toward the wallet.
The Credential Entry "type" array in the response MUST be
populated from the presented credential itself and MUST contain
the "type" value declared in this mapping.

An OP that additionally supports the DCQL-based request mode
({{dcql-based-requests}}) MUST include a JSON boolean member
"dcql_query_supported" in its discovery metadata with the value
`true`.  This member is OPTIONAL; if it is absent, RPs MUST treat
it as if it were present with the value `false`.  An OP that does
not support the DCQL-based mode MAY omit the member or set it
explicitly to `false`.

The following is a non-normative example of an RP discovering the
OP's supported credential types:

~~~ http
GET /.well-known/openid-configuration HTTP/1.1
Host: op.example.org
~~~

~~~ http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "issuer": "https://op.example.org",
  "authorization_endpoint": "https://op.example.org/authorize",
  "token_endpoint": "https://op.example.org/token",
  "userinfo_endpoint": "https://op.example.org/userinfo",
  "jwks_uri": "https://op.example.org/jwks.json",
  "credential_presentations_supported": {
    "ehic": {
      "format": "dc+sd-jwt",
      "type": "urn:eu.europa.ec.eudi:ehic:1"
    },
    "pda1": {
      "format": "dc+sd-jwt",
      "type": "urn:eu.europa.ec.eudi:pda1:1"
    }
  }
}
~~~

## Authentication Flow

When the OP receives an OIDC Authentication Request that includes
credential type scopes (and optionally a "dcql_query" member inside
the OIDC "claims" request parameter for fine-grained control), it
MUST:

1.  Validate that each credential type scope corresponds to a key
    in the OP's "credential_presentations_supported" metadata.  The
    OP MUST ignore any credential type scope that is not present in
    its metadata.  If none of the requested credential scopes are
    supported, the OP MUST return an OIDC error response.

2.  If the request includes a "dcql_query" member, validate it
    against the profile defined in {{dcql-based-requests}}.  If the
    OP does not support the DCQL-based mode, or the query does not
    conform to the profile, the OP MUST return an OIDC error
    response with error code "invalid_request".

3.  Initiate a credential presentation request to the user's wallet
    for the supported credential types, using the presentation
    protocol supported by the deployment.  When the RP supplied a
    "dcql_query", the OP SHOULD translate it into the corresponding
    presentation-protocol query (see {{app-dcql-binding}} for the
    DCQL binding).

4.  Verify the presented credentials according to the applicable
    trust framework, including any "trusted_authorities"
    constraints from the RP's "dcql_query".

5.  Extract the disclosed claims from each verified credential.

6.  Construct the "presented_credential_sets" object as defined in
    {{presented-credential-sets-array}}.

7.  Include the "presented_credential_sets" claim in the ID Token, the
    UserInfo response, or both, depending on the OP's policy and
    the size considerations described in {{claim-set-size-limits}}.

Common presentation protocols include OpenID4VP {{OpenID4VP}} and
DIDComm Present Proof.  The choice of protocol is a deployment
decision and does not affect the "presented_credential_sets" format
returned to the RP.

## Credential Mapping {#credential-mapping}

This section describes the protocol-agnostic mapping between the
OIDC-level request the RP sends to the OP and the credential data
the OP returns.  Concrete bindings to specific presentation
protocols are given in the appendices; the DCQL binding used with
OpenID4VP is defined in {{app-dcql-binding}}, and a placeholder for
a future DIDComm binding appears in {{app-didcomm-binding}}.

The OP uses the "credential_presentations_supported" discovery
metadata to translate scopes into credential queries.  For each
credential type scope in the authorization request, the OP looks
up the corresponding key in "credential_presentations_supported"
and uses the "format" and "type" values to construct the
presentation-protocol query.  The same key is used both to
identify the credential in the query toward the wallet and as the
key in the "presented_credential_sets" response.

The binding is:

*  The key in "credential_presentations_supported" (e.g., "ehic")
   is the scope value the RP includes in the authorization request,
   and MUST also be used as the Credential Query identifier in the
   presentation-protocol query.

*  The OP MUST use the "format" and "type" from the configuration
   entry to populate the presentation-protocol query's format and
   type-identifier parameters.

*  The OP MUST use this same value as a key inside the
   "credentials" object of the corresponding Credential Set in
   the "presented_credential_sets" response.  For example, if the RP
   requested scope "ehic", the resulting Credential Set's
   "credentials" object MUST contain an "ehic" key.

When the RP additionally supplied a "dcql_query" in the OIDC
"claims" request parameter ({{dcql-based-requests}}), the OP MUST
use the RP-chosen Credential Query "id" values as the keys within
the "credentials" object of the Credential Set.  Correlation to
"credential_presentations_supported" is by credential type, per
{{dcql-based-requests}}.

Response construction rules:

*  The OP MUST NOT include claims that were not disclosed by the
   wallet.
*  The OP MUST NOT modify claim values during the mapping.
*  When the RP used the DCQL-based mode and specified a non-empty
   "claims" array for a Credential Query, the OP MUST include only
   the requested claims in the corresponding Credential Entry's
   "claims" object.  Even if the wallet discloses additional claims
   (for example, because the credential format does not support
   selective disclosure), the OP MUST NOT relay unrequested claims
   to the RP.  This ensures data minimization regardless of the
   underlying credential format's selective disclosure
   capabilities.
*  When the RP used scope-based mode, or the RP's Credential Query
   omitted "claims", the OP includes the claim set configured for
   that credential type by deployment policy.

Constraint enforcement rules:

*  If a claim query in the RP's "dcql_query" specifies a "values"
   array and the disclosed claim value does not match any entry
   (using the matching rules in {{app-value-matching}}), the
   credential MUST be treated as not satisfying the query.
*  If the RP's "dcql_query" specifies "trusted_authorities" for a
   Credential Query and the presented credential does not chain to
   at least one listed authority, the credential MUST be treated as
   not satisfying the query.  Security requirements for
   dereferencing external trust material are given in
   {{trust-list-fetching}}.
*  If the RP's "dcql_query" includes "credential_sets", the OP MUST
   evaluate the alternation per Section 6.3 of {{OpenID4VP}}.  If
   no required Credential Set can be satisfied, the OP MUST return
   an OIDC error response (e.g., "access_denied").

Applicability of RP-supplied constraints:

*  In scope-based mode the RP cannot express selective-disclosure,
   value, or issuer constraints on a per-request basis; the OP
   applies its own policy.
*  In DCQL-based mode the RP can express selective disclosure via
   "path", value constraints via "values", and issuer or authority
   constraints via "trusted_authorities", within the profile
   defined in {{dcql-based-requests}}.
*  Constraints not expressible in this profile (for example,
   issuance date filters or compound field requirements) remain
   deployment policy.  The OP SHOULD document such policies so that
   RPs can anticipate the resulting behaviour.

The structure of the "presented_credential_sets" claim MUST be
independent of the credential presentation protocol used between
the OP and the wallet.  Whether the OP collected credentials via
OpenID4VP, DIDComm, or any other mechanism, the resulting claim
format MUST conform to this specification.  The RP MUST NOT need
to be aware of which presentation protocol was used.

## Deriving the sub Claim {#sub-derivation}

OpenID Connect Relying Parties depend on the "sub" claim as the
subject identifier for the authenticated user.  When credential
claims delivered via this specification form the basis of the
authentication, the OP populates "sub" from a designated identity
credential as follows.

The identity credential is selected in this order:

1.  If any Credential Entry in the "presented_credential_sets"
    response carries `"primary": true` (see
    {{credential-entry-object}}), that entry is the identity
    credential.  At most one such entry is permitted per
    Credential Set.

2.  Otherwise, if the first Credential Set in
    "presented_credential_sets" contains exactly one Credential
    Entry, that entry is the identity credential.

3.  Otherwise, the selection is implementation-defined and MUST
    be documented by the OP.

The OP derives a stable identifier from the identity credential
by reading the claim identified by the "subject_claim" configured
for the identity credential's type in
"credential_presentations_supported" (see {{discovery}}).  If no
"subject_claim" is configured for the type, the OP MUST document
its local selection rule.

The OP SHOULD use pairwise pseudonymous subject identifiers per
"client_id", derived from the stable identifier via a per-RP,
deployment-configured transformation (for example, an HMAC keyed
on the "client_id").  The OP MUST NOT surface a raw credential
subject identifier as "sub" unless the RP is explicitly
configured for public subject types.

If no identity credential can be selected, the OP MUST fail the
authentication request with OIDC error code "access_denied".

# Limitations and Considerations

## Claim Set Size Limits {#claim-set-size-limits}

OIDC ID Tokens are typically passed as JWTs {{RFC7519}} in HTTP headers
or URL fragments, which impose practical size limits.  Browser URL
length limits are commonly around 2048 bytes, and many HTTP servers
reject headers exceeding 8192 bytes.  When multiple credentials with
many disclosed claims are included in the "presented_credential_sets"
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
  the "presented_credential_sets" claim entirely or return an OIDC error
  response (e.g., "access_denied") depending on whether the
  credential presentation was essential to the authentication.

Wallet timeout
: The wallet does not respond within a reasonable time.  The OP
  SHOULD treat this as equivalent to a rejection.

Invalid credentials
: The wallet presents credentials that fail verification (expired,
  revoked, untrusted issuer).  The OP MUST NOT include unverified
  credential claims in the "presented_credential_sets" object.  The OP
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

## Fresh Presentation Requirement {#fresh-presentation}

Each OIDC Authentication Request that includes credential scopes
MUST result in a new credential presentation from the wallet.  The
OP MUST initiate a fresh presentation protocol transaction (e.g.,
OpenID4VP, DIDComm) for every authentication request and MUST NOT
reuse credentials from a previous presentation to satisfy a new
authentication request.

To enable idempotent UserInfo responses, an OP that delivers
"presented_credential_sets" via the UserInfo endpoint MAY retain the
credential claims needed to answer subsequent UserInfo requests
authorised by the access token issued for the current
authentication.  Any such retention is subject to the following
requirements:

*  The OP MUST discard the retained credential claims at or
   before the expiry of that access token, and MUST discard them
   immediately upon revocation of the access token.

*  The OP MUST NOT use retained credential claims to satisfy any
   subsequent OIDC Authentication Request; a fresh presentation
   is always required per the paragraph above.

*  The OP MUST NOT persist credential claims to durable storage
   beyond what is strictly necessary to answer UserInfo requests
   authorised by that specific access token.

When "presented_credential_sets" is delivered only in the ID Token,
the OP MUST discard the credential claims once the ID Token has
been issued.  In all cases the OP MUST NOT become a general
repository of credential data across authentications.  This ensures that
credential freshness is guaranteed and that the OP does not become
an unnecessary repository of sensitive personal data.

## Scope of This Specification

This specification defines the data format of the
"presented_credential_sets" claim, the mechanism for requesting and
returning credential claims via OIDC, and the responsibilities of the
OP and RP in that exchange.  The following aspects are explicitly out
of scope:

*  *Credential validation policy.* This specification does not define
   which issuers to trust, which revocation mechanisms to check, or
   what trust frameworks to apply.  These decisions are deployment-
   specific and determined by the OP operator.

*  *Business logic and authorization decisions.* How the RP
   interprets the received claims -- for example, whether an EHIC
   credential grants access to a healthcare service, or whether a
   PDA1 is sufficient for a given transaction -- is entirely the RP's
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
-- trust decisions, access control, and business rules -- is the domain
of the deploying parties.

# Security Considerations

## Credential Replay

The OP MUST ensure that credential presentations are bound to the
current authentication session.  The OP SHOULD use nonces in the
OpenID4VP request to prevent replay of previously captured VP Tokens.

When the OP uses OpenID4VP as the presentation protocol and the
authentication request carries a "nonce" parameter, the OpenID4VP
request "nonce" MUST be byte-identical to that OIDC "nonce" value.
This binds the credential presentation to the OIDC session without
introducing a second nonce that the RP would have to reconcile
separately.  If the authentication request does not carry a
"nonce", the OP MUST generate a fresh nonce, use it as both the
OpenID4VP request nonce and the ID Token "nonce" claim, and thereby
preserve the same binding.

The RP MUST validate standard JWT claims ("iat", "exp", "nonce") in
the ID Token to ensure freshness of the "presented_credential_sets"
claim.

## Token Leakage

ID Tokens containing "presented_credential_sets" may carry sensitive
personal data (e.g., national ID numbers, health information).
Implementations MUST use TLS for all token transmissions.  The OP
SHOULD prefer delivering credential claims via the UserInfo endpoint
(which uses a back-channel request) rather than embedding them in the
ID Token (which may be exposed in browser history or logs).

## Claim Injection

The OP MUST NOT allow external parties to inject or modify claims
within the "presented_credential_sets" object.  The OP MUST populate this
claim exclusively from verified credential presentations.  The ID
Token MUST be signed by the OP to protect integrity.

## Trust Authority Dereferencing {#trust-list-fetching}

When the OP dereferences external references contained in a
"trusted_authorities" entry supplied via the RP's "dcql_query"
(such as an "etsi_tl" trust list URI or an "openid_federation"
entity identifier), it MUST enforce the following safeguards:

*  The OP MUST only fetch external trust material over HTTPS.

*  The OP MUST NOT dereference arbitrary URIs provided by an RP.
   The OP MUST restrict which URIs it is willing to fetch to
   prevent Server-Side Request Forgery (SSRF).  The mechanism for
   this restriction (e.g., an allowlist, domain policy) is a
   deployment decision and outside the scope of this specification.

*  The OP MUST impose size limits on fetched documents to prevent
   resource exhaustion.

*  The OP SHOULD cache dereferenced trust material and enforce a
   minimum refresh interval to limit the impact of a compromised or
   unavailable remote trust material source.

*  If an external trust reference supplied by the RP is off the
   OP's allowlist, the OP MUST treat that "trusted_authorities"
   entry as contributing no authorities.  When every entry in the
   same "trusted_authorities" array is off-allowlist, the OP MUST
   return an OIDC error response with error code
   "invalid_request" and error description
   "trusted_authority_not_allowed" so that the RP can distinguish
   an allowlist rejection from an unsatisfied query.
   Off-allowlist entries in an array that also contains at least
   one on-allowlist entry MUST be silently ignored; the request
   proceeds with the remaining entries.

*  If an on-allowlist external trust reference cannot be fetched
   or parsed, the OP MUST treat that "trusted_authorities" entry
   as contributing no authorities.  Other entries in the same
   "trusted_authorities" array that were successfully resolved
   still apply.  The OP MUST NOT treat an unresolved entry as
   matching all authorities.

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

The claim name "presented_credential_sets" was chosen to be protocol-
agnostic, clearly describing the content (credentials that were
presented) without implying a dependency on any particular
presentation protocol or namespace.

## JSON Web Token Claims Registration

This specification requests registration of the following claim in
the IANA "JSON Web Token Claims" registry:

Claim Name
: "presented_credential_sets"

Claim Description
: Digital credential claims obtained via a credential presentation
  flow, structured for consumption by OIDC Relying Parties.

Change Controller
: IETF

Specification Document(s)
: {{presented-credential-sets-array}} of this document

## OpenID Connect Discovery Metadata Registration

This specification requests registration of the following metadata
parameters:

Metadata Name
: "credential_presentations_supported"

Metadata Description
: A JSON object describing the credential types the OP can collect
  via credential presentation and expose as OIDC claims.

Change Controller
: IETF

Specification Document(s)
: {{discovery}} of this document

Metadata Name
: "dcql_query_supported"

Metadata Description
: A JSON boolean indicating whether the OP accepts a "dcql_query"
  member inside the OIDC "claims" request parameter as defined in
  the DCQL-based request mode.

Change Controller
: IETF

Specification Document(s)
: {{discovery}} of this document

## Credential Trust Status Values Registry {#trust-status-registry}

This specification establishes the "Credential Trust Status Values"
registry.  The registration policy is "Specification Required" as
defined in Section 4.6 of {{!RFC8126}}.

Each entry in the registry contains the following fields:

Value
: A short string used as the value of the "trust_status" member of
  the Credential Entry "verification" object.

Description
: A brief description of the trust-status semantics.

Change Controller
: The entity responsible for the registration.

Specification Document(s)
: Reference to the specification defining the value.

The initial contents of the registry are:

| Value | Description | Change Controller | Specification |
|:---|:---|:---|:---|
| not_checked | The OP performed no trust-status check for this credential | IETF | {{credential-entry-object}} of this document |
| unknown | The OP performed a trust-status check but the authoritative source returned no conclusive answer (e.g., ETSI Token Status List "unknown" state) | IETF | {{credential-entry-object}} of this document |
| valid | The credential's trust status was checked and is currently valid | IETF | {{credential-entry-object}} of this document |
| suspended | The credential is temporarily suspended by its issuer or trust framework | IETF | {{credential-entry-object}} of this document |
| revoked | The credential has been revoked by its issuer or trust framework | IETF | {{credential-entry-object}} of this document |
| expired | The credential has expired according to its own validity period | IETF | {{credential-entry-object}} of this document |
| invalid | The credential failed one or more verification checks | IETF | {{credential-entry-object}} of this document |

## Credential Holder Binding Methods Registry {#holder-binding-registry}

This specification establishes the "Credential Holder Binding
Methods" registry.  The registration policy is "Specification
Required" as defined in Section 4.6 of {{!RFC8126}}.

Each entry in the registry contains the following fields:

Method Name
: A short string identifying the holder binding method.

Description
: A brief description of the method.

Change Controller
: The entity responsible for the registration.

Specification Document(s)
: Reference to the specification defining the method.

The initial contents of the registry are:

| Method Name | Description | Change Controller | Specification |
|:---|:---|:---|:---|
| key_binding | Cryptographic proof of possession of a private key bound to the credential | IETF | {{credential-entry-object}} of this document |
| biometric | Biometric verification of the presenter against data bound to the credential | IETF | {{credential-entry-object}} of this document |
| pin | Verification of a PIN or passcode known to the credential holder | IETF | {{credential-entry-object}} of this document |

--- back

# DCQL Binding {#app-dcql-binding}

This appendix defines the concrete binding between the OIDC-level
request defined in {{requesting-credential-claims}} and DCQL as
specified in Section 6 of {{OpenID4VP}}.  Deployments that use
OpenID4VP as the presentation protocol between the OP and the
wallet MUST follow this binding; other bindings are out of scope
of this appendix.

## Scope-Based Mode

For each credential type scope in the authorization request, the
OP constructs one DCQL Credential Query as follows:

*  The scope value is used verbatim as the DCQL Credential Query
   "id".
*  The "format" is taken from the corresponding entry in
   "credential_presentations_supported".
*  The "meta" member is populated from the entry's "type": for
   the `dc+sd-jwt` format the OP sets `meta.vct_values` to a JSON
   array containing the "type" string; for the `mso_mdoc` format
   the OP sets `meta.doctype_value` to the "type" string.
*  The "claims" array is either omitted or set to the deployment's
   pre-registered claim set for the credential type.

For example, given the discovery metadata:

~~~ json
{
  "credential_presentations_supported": {
    "ehic": {
      "format": "dc+sd-jwt",
      "type": "urn:eu.europa.ec.eudi:ehic:1"
    },
    "pda1": {
      "format": "dc+sd-jwt",
      "type": "urn:eu.europa.ec.eudi:pda1:1"
    }
  }
}
~~~

and an RP request with `scope=openid ehic pda1`, the OP constructs
the following DCQL query:

~~~ json
{
  "credentials": [
    {
      "id": "ehic",
      "format": "dc+sd-jwt",
      "meta": {
        "vct_values": ["urn:eu.europa.ec.eudi:ehic:1"]
      }
    },
    {
      "id": "pda1",
      "format": "dc+sd-jwt",
      "meta": {
        "vct_values": ["urn:eu.europa.ec.eudi:pda1:1"]
      }
    }
  ]
}
~~~

The wallet returns a VP Token keyed by these same "id" values,
allowing the OP to map presented credentials back to the
corresponding scope.

## DCQL-Based Mode

When the RP supplied a "dcql_query" member in the OIDC "claims"
request parameter, the OP MUST use that query as the DCQL query
sent to the wallet, subject to the following:

*  RP-supplied Credential Query "id" values are forwarded to the
   wallet unchanged.
*  Each Credential Query MUST satisfy the type and scope checks
   of {{dcql-based-requests}}; otherwise the OP MUST reject the
   request.
*  Coverage: a scope in the authorization request is considered
   covered by the RP-supplied "dcql_query" when at least one
   RP-supplied Credential Query targets the credential type that
   scope maps to in "credential_presentations_supported" (see
   {{dcql-based-requests}}).
*  Augmentation: for every uncovered scope, the OP MUST add a
   Credential Query derived from that scope using the scope-based
   rules of {{app-dcql-binding}} above.  Covered scopes MUST NOT
   be augmented.
*  Naming: every OP-augmented Credential Query "id" MUST be the
   string `bridge:` concatenated with the scope value (for
   example, the augmented query for scope "ehic" has
   `"id": "bridge:ehic"`).
*  Reservation: the RP MUST NOT use a Credential Query "id" that
   begins with `bridge:`.  If any RP-supplied "id" begins with
   `bridge:`, the OP MUST reject the request with OIDC error
   code "invalid_request".
*  The OP MUST NOT relax any constraint expressed by the RP
   (e.g., MUST NOT drop "trusted_authorities" or widen "values").

## Response Mapping

For each satisfied Credential Query, the OP populates a Credential
Entry as defined in {{credential-entry-object}}.  The DCQL
Credential Query "id" becomes a key inside the "credentials"
object of the enclosing Credential Set in the
"presented_credential_sets" response.

When the RP's "dcql_query" contains "credential_sets", the OP
returns one Credential Set object in the "presented_credential_sets"
array for each satisfied entry in "credential_sets", populated
with the Credential Entries from the matched AND-group.  The
OPTIONAL "id" of each Credential Set entry MAY be echoed in the
response via the "credential_set_id" member described in
{{presented-credential-sets-array}}.

## Value Constraint Propagation

DCQL value matching is defined as best-effort: the wallet SHOULD
filter on the constraint but is not required to do so (see Section
6.4.1 of {{OpenID4VP}}).  Consequently, the OP MUST NOT rely on
the wallet to enforce "values" constraints and MUST always
validate disclosed claim values against the RP's "values"
requirements after receiving the presentation.  Propagating the
constraint to the wallet remains useful as a privacy optimisation,
because it allows the wallet to avoid disclosing credentials that
would not satisfy the request.

When a disclosed credential fails post-presentation "values"
re-validation, the OP MUST treat the wallet as not having
disclosed a matching credential for the corresponding Credential
Query.  If that leaves a Credential Query marked `"required":
true` in the enclosing "credential_sets" option unsatisfied, and
no other Credential Query satisfies the option, the OP MUST
return an OIDC error response with error code "access_denied".
The OP MUST NOT silently drop the offending Credential Entry from
the "presented_credential_sets" response while retaining other
disclosed claims from the same credential.

# DIDComm Binding {#app-didcomm-binding}

This appendix is reserved for a future DIDComm Present Proof
binding.  Its inclusion is intended to make the extension pattern
explicit: bindings for additional presentation protocols may be
added here without changing the protocol-agnostic contract in
{{credential-mapping}}.

# Claim Value Matching {#app-value-matching}

Several normative rules in this specification require comparing a
disclosed claim value against entries in a "values" array.  A
disclosed value matches an entry if and only if both are of the
same JSON type (as defined in {{RFC8259}}) and are equal under the
following rules:

*  Strings are compared as sequences of Unicode code points.  No
   Unicode normalization, case folding, or whitespace trimming is
   applied.

*  Numbers are compared by mathematical value, independent of their
   lexical representation (for example, `1`, `1.0`, and `1e0` all
   match).

*  Boolean values match only the identical boolean, and the null
   value matches only null.

Values of different JSON types never match (for example, the string
"1" does not match the number 1).

Objects and arrays MAY appear in "values" entries.  Two arrays are
equal if and only if they have the same length and each element
pair matches recursively under these rules.  Two objects are equal
if and only if they have the same set of member names and each
member value matches recursively under these rules.  Object member
order is not significant.

# Acknowledgments
{:numbered="false"}

The author would like to thank Patrick Amrein (Ubique) for reviews,
comments, and contributions to this document.
