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
    the "presented_credentials" claim.

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
: A JSON object within the "presented_credentials" array where
  each key is a credential type scope and each value is an array
  of Credential Entry objects.

Credential Entry
: A JSON object representing a single credential presented during
  the presentation flow, containing metadata and disclosed claims.

# Relying Party Requirements

## Requesting Credential Claims {#requesting-credential-claims}

An RP that wishes to receive credential data via this bridge MUST
include credential type scopes in the OIDC Authentication Request
(e.g., `scope=openid ehic pda1`).  Scopes are always required
because they tell the OP which credential types to collect.  The RP
MAY additionally include a "requested_credential_sets" claims
parameter for fine-grained control.

*  *Scope-based (simple):* Include only credential type scopes.
   The OP requests all available claims for those credential types
   and returns them in the response.  This approach requires no
   additional parameters but offers no selective disclosure or
   value constraints from the RP side.

*  *Scope + claims-based (detailed):* Include credential type scopes
   AND a "requested_credential_sets" member inside the OIDC "claims"
   request parameter (within the "id_token" or "userinfo" entry).
   This gives the RP fine-grained control: which specific claims to
   request, whether each is essential or optional, value constraints,
   and trusted issuer requirements.

Scopes identify which credentials to collect, and the
"requested_credential_sets" claims parameter (when present) specifies
how to collect them.  If only scopes are present without a
"requested_credential_sets" claims parameter, the OP requests all
available claims for the given credential types.

The following is a non-normative example of a scope-based request
(no claims parameter).  The RP requests EHIC and PDA1 credentials
with all available claims:

~~~ http
GET /authorize?
  response_type=code
  &scope=openid ehic pda1
  &client_id=https://rp.example.org
  &redirect_uri=https://rp.example.org/cb
  &nonce=n-0S6_WzA2Mj HTTP/1.1
~~~

The requested scopes directly correlate to the keys in credential
sets returned by the OP.  For example, if the RP requests scopes
"ehic" and "pda1", the OP will return a credential set containing
"ehic" and "pda1" entries.

The RP MAY additionally use the "claims" request parameter to specify
which individual claims within a credential type are desired,
enabling selective disclosure.

The "claims" member within a credential type entry is a JSON array
of claim query objects.  Each claim query object contains the
following members:

path
: REQUIRED.  A non-empty JSON array of strings representing the
  path to the claim within the credential, following the Claims
  Path Pointer syntax defined in Section 7 of {{OpenID4VP}}.
  For top-level claims the array contains a single string
  (e.g., `["name"]`).  For nested claims the array contains one
  element per level (e.g., `["address", "street_address"]`).

essential
: OPTIONAL.  A boolean indicating whether the claim MUST be
  disclosed.  Defaults to true if omitted.

value
: OPTIONAL.  A JSON value that the disclosed claim MUST exactly
  equal.  If present, the OP MUST verify that the disclosed claim
  value matches and MUST treat the credential as not satisfying
  the request if it does not.  If omitted, any disclosed value is
  accepted.

The "requested_credential_sets" member is placed inside the OIDC
"claims" request parameter as permitted by Section 5.5.1 of
{{OpenID.Core}}.  Its value is a JSON array of credential set
objects, each representing one combination of credentials to request.

Each credential type entry within a credential set MAY also include
the following optional members to express trust requirements:

trusted_issuers
: A JSON array of strings, where each string is an issuer identifier.
  When present, the OP MUST only accept credentials issued by one of
  the listed issuers.  If the wallet presents a credential from an
  issuer not in this list, the OP MUST treat it as not satisfying the
  request.  If omitted, the OP applies its own issuer policy.

trusted_issuer_lists
: A JSON array of strings, where each string is an HTTPS URI
  identifying a published trust list.  The trust list is a JSON
  document containing an "issuers" member whose value is a JSON array
  of issuer identifier strings in the same format as
  "trusted_issuers".  The OP MUST fetch and cache each referenced
  trust list and MUST accept credentials from any issuer appearing in
  at least one of the referenced lists.  When both "trusted_issuers"
  and "trusted_issuer_lists" are present, the effective set of
  trusted issuers is the union of the explicitly listed issuers and
  the issuers from all referenced lists.  If both members are omitted,
  the OP applies its own issuer policy.

The following is a non-normative example requesting a PID from a
specific set of trusted issuers:

~~~ json
{
  "id_token": {
    "requested_credential_sets": [
      {
        "pid": {
          "essential": true,
          "claims": [
            {"path": ["name"]},
            {"path": ["birth_date"]}
          ],
          "trusted_issuers": [
            "https://pid.example.gov.se",
            "https://pid.example.gov.no"
          ]
        }
      }
    ]
  }
}
~~~

The following is a non-normative example using trust lists to accept
PID and EHIC credentials from all issuers recognized by the EU trust
list, without enumerating each issuer individually:

~~~ json
{
  "id_token": {
    "requested_credential_sets": [
      {
        "pid": {
          "essential": true,
          "claims": [
            {"path": ["name"]},
            {"path": ["birth_date"]}
          ],
          "trusted_issuer_lists": [
            "https://trust.eu.example.org/pid-issuers.json"
          ]
        },
        "ehic": {
          "essential": true,
          "claims": [
            {"path": ["ehic_number"]}
          ],
          "trusted_issuer_lists": [
            "https://trust.eu.example.org/ehic-issuers.json"
          ]
        }
      }
    ]
  }
}
~~~

The following is a non-normative example of a trust list document
served at the URI referenced above:

~~~ json
{
  "issuers": [
    "https://pid.example.gov.se",
    "https://pid.example.gov.no",
    "https://pid.example.gov.de",
    "https://pid.example.gov.fr"
  ]
}
~~~

The "requested_credential_sets" array MUST contain at least one
credential set entry.  The structure expresses combinatorial logic
over credential types:

*  *AND (within a set):* Credentials listed in the same credential
   set with "essential": true are all required for that set to be
   considered satisfied.  If any essential credential in the set
   cannot be obtained, the set is not satisfied and the OP proceeds
   to the next alternative set.  The following is a non-normative
   example requesting PID AND EHIC together (both are required):

~~~ json
{
  "id_token": {
    "requested_credential_sets": [
      {
        "pid": {
          "essential": true,
          "claims": [
            {"path": ["name"]}
          ]
        },
        "ehic": {
          "essential": true,
          "claims": [
            {"path": ["ehic_number"]}
          ]
        }
      }
    ]
  }
}
~~~

*  *OR (between sets):* Multiple credential sets represent
   alternatives.  The OP MUST attempt to satisfy the sets in order
   and use the first set that can be fully satisfied.  Only one
   credential set is returned in the response.  If no set can be
   fully satisfied, the OP MUST return an OIDC error response
   (e.g., "access_denied").  The following is a non-normative
   example requesting PID OR EHIC (either one satisfies the RP).
   The OP tries the first set; if the wallet cannot provide a PID,
   it falls back to the second set:

~~~ json
{
  "id_token": {
    "requested_credential_sets": [
      {
        "pid": {
          "essential": true,
          "claims": [
            {"path": ["name"]}
          ]
        }
      },
      {
        "ehic": {
          "essential": true,
          "claims": [
            {"path": ["ehic_number"]}
          ]
        }
      }
    ]
  }
}
~~~

This structure is equivalent to Disjunctive Normal Form (DNF): a
flat list of AND-groups joined by OR.  It cannot directly express
an OR nested inside an AND.  For example, the requirement
"(PID OR EHIC) AND PDA1" must be manually expanded into two
credential sets: {PID, PDA1} OR {EHIC, PDA1}.  Complex boolean
combinations may therefore require a number of credential sets that
grows multiplicatively with the number of OR-branches.

The following is a non-normative example requesting PID (required)
with EHIC as optional (nice-to-have):

~~~ json
{
  "id_token": {
    "requested_credential_sets": [
      {
        "pid": {
          "essential": true,
          "claims": [
            {"path": ["name"]}
          ]
        },
        "ehic": {
          "essential": false,
          "claims": [
            {"path": ["ehic_number"]}
          ]
        }
      }
    ]
  }
}
~~~

The following is a non-normative example requesting a PID with a
value constraint and an optional claim:

~~~ json
{
  "id_token": {
    "requested_credential_sets": [
      {
        "pid": {
          "essential": true,
          "claims": [
            {"path": ["name"], "essential": true},
            {"path": ["age_over_18"], "essential": true, "value": true},
            {"path": ["email"], "essential": false}
          ]
        }
      }
    ]
  }
}
~~~

In the above example the OP MUST ensure the wallet discloses "name"
and "age_over_18", and that "age_over_18" equals true.  The "email"
claim is requested but not required; the OP SHOULD request it from
the wallet but MUST NOT fail if the wallet does not disclose it.

The following is a non-normative example requesting nested claims
from a PID credential:

~~~ json
{
  "id_token": {
    "requested_credential_sets": [
      {
        "pid": {
          "essential": true,
          "claims": [
            {"path": ["name"]},
            {"path": ["address", "street_address"]},
            {"path": ["address", "country"], "value": "SE"}
          ]
        }
      }
    ]
  }
}
~~~

If the wallet presents multiple credentials of the same type (e.g.,
two EHICs for different family members), the OP returns all of them
in the array.  The RP is responsible for selecting the appropriate
credential by inspecting the returned claims (for example, matching
on name or date of birth against the authenticated user's identity).

## Consuming Credential Claims

The "presented_credentials" claim structure is defined in
{{presented-credentials-claim}}.  The RP MUST parse the claim according to that
definition.  Specifically, the RP MUST:

1.  Check for the presence of the "presented_credentials" claim.  If
    the claim was requested as essential and is absent, the RP SHOULD
    treat the authentication as failed.

2.  Parse the "presented_credentials" array and extract the
    Credential Set objects relevant to its use case.

3.  Validate that the expected claims are present in each Credential
    Entry's "claims" object.  If the RP specified a "value"
    constraint for a claim, verify that the returned value matches.

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

## The presented_credentials Claim {#presented-credentials-claim}

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
          "type": "https://credential.example.org/ehic/1.0",
          "issuer": "https://svs.example.se",
          "valid_from": 1709251200,
          "valid_until": 1740787200,
          "verified_at": 1722772700,
          "verification": {
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
          "type": "https://credential.example.org/pda1/1.0",
          "issuer": "https://tax.example.se",
          "valid_from": 1709251200,
          "valid_until": 1740787200,
          "verified_at": 1722772700,
          "verification": {
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
  ]
}
~~~

### The presented_credentials Array {#presented-credentials-array}

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
during the presentation flow.  It MUST contain the following members:

type
: A string identifying the credential type.  The value is protocol-
  specific: for SD-JWT VC credentials it is the Verifiable Credential
  Type (vct), for mdoc credentials it is the docType, and for other
  formats it is whatever type identifier the credential format
  defines.  The OP MUST set this field based on the presented
  credential.

claims
: A JSON object {{RFC8259}} containing the disclosed claims from the
  credential.  Each key is a claim name and each value is the claim
  value.  Claim names are determined by the credential type and MUST
  be strings.  Claim values MAY be any valid JSON type.

It MAY contain the following additional members:

issuer
: A string identifying the entity that issued the credential.  For
  SD-JWT VC credentials this is the "iss" claim value, for mdoc
  credentials it is the issuing authority identifier.  The OP SHOULD
  populate this field to allow the RP to make issuer-aware
  authorization decisions.

valid_from
: A NumericDate (as defined in {{RFC7519}}) indicating when the
  credential became valid (i.e., the issuance or activation date).

valid_until
: A NumericDate indicating when the credential expires.  The OP
  MUST NOT include credentials that have already expired at the time
  of presentation.

verified_at
: A NumericDate indicating when the OP verified the credential
  during the presentation flow.  This allows the RP to assess the
  freshness of the verification relative to its own requirements.

verification
: A JSON object providing metadata about the verification the OP
  performed on the credential.  This object MAY contain the
  following members:

  holder_binding
  : A string describing the mechanism used to verify that the
    presenter is the legitimate holder of the credential.  Values
    are taken from the "Credential Holder Binding Methods" registry
    defined in {{holder-binding-registry}}.

  Additional members within the "verification" object MAY be present.
  Implementations that do not recognise additional members MUST
  ignore them.

The following is a non-normative example of a Credential Entry with
nested claims, as might appear in a PID credential:

~~~ json
{
  "type": "urn:eu.europa.ec.eudi:pid:1",
  "issuer": "https://pid.example.gov.se",
  "valid_from": 1709251200,
  "valid_until": 1740787200,
  "verified_at": 1722772700,
  "verification": {
    "holder_binding": "key_binding"
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

Additional members MAY be present.  Implementations that do not
recognise additional members MUST ignore them.

## Discovery

An OP that supports this bridge mechanism MUST include
"presented_credentials" in the "claims_supported" list in its OpenID
Connect Discovery {{OpenID.Discovery}} metadata document.

The OP MUST include a "credential_presentations_supported" member
in its discovery metadata.  This is a JSON object where each key is
a scope value that the RP can use in the authorization request, and
each value is an object describing the credential type configuration.
Each configuration object MUST contain at minimum:

format
: A string identifying the credential format (e.g., "dc+sd-jwt",
  "mso_mdoc").

type
: A string identifying the credential type.  For SD-JWT VC
  credentials this is the vct value; for mdoc credentials this is
  the docType.

The OP uses this metadata to translate the RP's scope request into
the correct credential query (e.g., a DCQL query with the
appropriate "vct_values" or "doctype_value") toward the wallet.
The Credential Entry "type" field in the response MUST be populated
from the presented credential itself and MUST match the "type" value
declared in this mapping.

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

When the OP receives an OIDC Authentication Request that includes a
request for credentials (via the "requested_credential_sets" claims
parameter or a registered scope), it MUST:

1.  Validate that each credential type scope corresponds to a key in
    the OP's "credential_presentations_supported" metadata.  The OP
    MUST ignore any credential type scope that is not present in its
    metadata.  If none of the requested credential scopes are
    supported, the OP MUST return an OIDC error response.

2.  Initiate a credential presentation request to the user's wallet
    for the supported credential types, using the presentation
    protocol supported by the deployment.

3.  Verify the presented credentials according to the applicable
    trust framework.

4.  Extract the disclosed claims from each verified credential.

5.  Construct the "presented_credentials" object as defined in
    {{presented-credentials-array}}.

6.  Include the "presented_credentials" claim in the ID Token, the
    UserInfo response, or both, depending on the OP's policy and the
    size considerations described in {{claim-set-size-limits}}.

Common presentation protocols include OpenID4VP {{OpenID4VP}} and
DIDComm Present Proof.  The choice of protocol is a deployment
decision and does not affect the "presented_credentials" format
returned to the RP.

## Credential Mapping

The OP uses the "credential_presentations_supported" discovery
metadata to translate scopes into credential queries.  For each
credential type scope in the authorization request, the OP looks up
the corresponding key in "credential_presentations_supported" and
uses the "format" and "type" values to construct the presentation
request.  The same key is used as the DCQL "id" and as the key in
the "presented_credentials" response.

The binding is:

*  The key in "credential_presentations_supported" (e.g., "ehic")
   is the scope value the RP includes in the authorization request.

*  The OP MUST use this same value as the "id" in the DCQL
   Credential Query.

*  The OP MUST use the "format" and "type" from the configuration
   entry to populate the DCQL "format" and "meta" fields.

*  The OP MUST use this same value as the key in the
   "presented_credentials" response.

For example, given the following discovery metadata:

~~~ json
{
  "credential_presentations_supported": {
    "ehic": {
      "format": "dc+sd-jwt",
      "type": "urn:eu.europa.ec.eudi:ehic:1"
    }
  }
}
~~~

and an RP request with `scope=openid ehic pda1`, the OP constructs:

~~~ json
{
  "credentials": [
    {
      "id": "ehic",
      "format": "dc+sd-jwt",
      "meta": { "vct_values": ["urn:eu.europa.ec.eudi:ehic:1"] },
      "claims": []
    },
    {
      "id": "pda1",
      "format": "dc+sd-jwt",
      "meta": { "vct_values": ["urn:eu.europa.ec.eudi:pda1:1"] },
      "claims": []
    }
  ]
}
~~~

The wallet returns a VP Token keyed by these same "id" values,
allowing the OP to map results back to the corresponding scope.

The OP MUST use the scope value as the key within the
"presented_credentials" response object.  For example, if the RP
requested scope "ehic", the resulting entry MUST be keyed as "ehic".
This ensures a predictable, stable mapping between the RP's request
and the response.

The OP MUST NOT include claims that were not disclosed by the wallet.
The OP MUST NOT modify claim values during the mapping.

When the RP uses the claims-based request mechanism (with explicit
"path" entries), the OP MUST include only the requested claims in the
Credential Entry's "claims" object.  Even if the wallet discloses
additional claims (for example, because the credential format does
not support selective disclosure), the OP MUST NOT relay unrequested
claims to the RP.  This ensures data minimization regardless of the
underlying credential format's selective disclosure capabilities.

When the RP uses scope-only (no "requested_credential_sets" claims
parameter), the OP includes all claims disclosed by the wallet, since
the RP did not express a preference for specific claims.

The OP MUST enforce claim-level constraints specified in the
"claims" array:

*  If a claim query has "essential": true (or the default applies)
   and the wallet does not disclose the claim identified by "path",
   the credential MUST be treated as not satisfying the request.

*  If a claim query specifies a "value" member and the disclosed
   value does not exactly match (using JSON value equality as
   defined in {{RFC8259}}), the credential MUST be treated as not
   satisfying the request.

*  Claim queries with "essential": false that are not disclosed by
   the wallet MAY be omitted from the Credential Entry without
   failing the request.

The OP translates each "path" array directly into the corresponding
DCQL Claims Path Pointer when constructing the presentation query
toward the wallet.

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

When the RP's request includes a "value" constraint on a claim, the
OP SHOULD propagate this constraint to the wallet where the
presentation protocol supports it.  The RP's "path" arrays map
directly to DCQL Claims Path Pointers, and the "value" member maps
to the DCQL "values" array.  For example, an RP request containing:

~~~ json
"claims": [
  { "path": ["name"] },
  { "path": ["address", "country"], "value": "SE" }
]
~~~

would translate to the following DCQL Claims Query entries:

~~~ json
{
  "credentials": [
    {
      "id": "ehic",
      "format": "dc+sd-jwt",
      "meta": {
        "vct_values": [
          "urn:credential:ehic"
        ]
      },
      "claims": [
        {"path": ["name"]},
        {"path": ["address", "country"], "values": ["SE"]}
      ]
    }
  ]
}
~~~

However, DCQL value matching is defined as best-effort: the wallet
SHOULD filter on the constraint but is not required to do so (see
Section 6.4.1 of {{OpenID4VP}}).  Consequently, the OP MUST NOT rely
on the wallet to enforce value constraints and MUST always validate
disclosed claim values against the RP's "value" requirements after
receiving the presentation.  Propagating the constraint to the wallet
remains useful as a privacy optimisation, because it allows the
wallet to avoid disclosing credentials that would not satisfy the
request.

The OIDC request model (scopes and the "claims" parameter) is
intentionally simpler than the query languages available in
presentation protocols (e.g., DCQL in OpenID4VP).  This means that
certain constraints expressible in a presentation query -- such as
issuer restrictions, issuance date filters, or compound field
requirements -- cannot be communicated by the RP.  The OP MUST apply
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

## Fresh Presentation Requirement {#fresh-presentation}

Each OIDC Authentication Request that includes credential scopes
MUST result in a new credential presentation from the wallet.  The
OP MUST initiate a fresh presentation protocol transaction (e.g.,
OpenID4VP, DIDComm) for every authentication request and MUST NOT
reuse credentials from a previous presentation.

The OP MUST NOT store, cache, or persist credential data beyond the
scope of the current authentication transaction.  Once the OP has
constructed the ID Token or UserInfo response and delivered it to
the RP, it MUST discard the credential claims.  This ensures that
credential freshness is guaranteed and that the OP does not become
an unnecessary repository of sensitive personal data.

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
: Magnus Svensson (masv@sunet.se)

Source Code
: Available at https://github.com/SUNET/vc (open source,
  BSD-2-Clause)

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

## Trust List Fetching

When the OP dereferences "trusted_issuer_lists" URIs provided by an
RP, it MUST enforce the following safeguards:

*  The OP MUST only fetch trust lists over HTTPS.

*  The OP MUST NOT dereference arbitrary URIs provided by an RP.
   The OP MUST restrict which trust list URIs it is willing to fetch
   to prevent Server-Side Request Forgery (SSRF).  The mechanism for
   this restriction (e.g., an allowlist, domain policy) is a
   deployment decision and outside the scope of this specification.

*  The OP MUST impose size limits on fetched trust list documents to
   prevent resource exhaustion.

*  The OP SHOULD cache trust lists and enforce a minimum refresh
   interval to limit the impact of a compromised or unavailable trust
   list endpoint.

*  If a trust list cannot be fetched or parsed, the OP MUST treat it
   as if no issuers were listed in that list.  The OP MUST NOT fall
   back to accepting all issuers.

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
: "presented_credentials"

Claim Description
: Digital credential claims obtained via a credential presentation
  flow, structured for consumption by OIDC Relying Parties.

Change Controller
: IETF

Specification Document(s)
: {{presented-credentials-array}} of this document

## OpenID Connect Discovery Metadata Registration

This specification requests registration of the following metadata
parameter:

Metadata Name
: "credential_presentations_supported"

Metadata Description
: A JSON object describing the credential types the OP can collect
  via credential presentation and expose as OIDC claims.

Change Controller
: IETF

Specification Document(s)
: {{discovery}} of this document

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

# Acknowledgments
{:numbered="false"}

TODO acknowledge.
