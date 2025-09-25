(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INVALID-INPUT (err u400))
(define-constant ERR-NODE-NOT-FOUND (err u404))
(define-constant ERR-EDGE-NOT-FOUND (err u405))
(define-constant ERR-INSUFFICIENT-REPUTATION (err u402))
(define-constant ERR-NODE-EXISTS (err u403))
(define-constant ERR-ALREADY-VOTED (err u406))
(define-constant ERR-INVALID-RELATIONSHIP (err u407))
(define-constant ERR-INVALID-STATUS (err u408))
(define-constant ERR-NOT-CONTRIBUTOR (err u409))
(define-constant ERR-ALREADY-VERIFIED (err u410))
(define-constant ERR-INSUFFICIENT-CONSENSUS (err u411))
(define-constant ERR-CITATION-REQUIRED (err u412))

(define-constant CONTRACT-OWNER tx-sender)

(define-constant NODE-TYPE-CONCEPT u1)
(define-constant NODE-TYPE-FACT u2)
(define-constant NODE-TYPE-ENTITY u3)
(define-constant NODE-TYPE-EVENT u4)
(define-constant NODE-TYPE-DEFINITION u5)

(define-constant EDGE-TYPE-IS-A u1)
(define-constant EDGE-TYPE-HAS-PROPERTY u2)
(define-constant EDGE-TYPE-RELATES-TO u3)
(define-constant EDGE-TYPE-CAUSES u4)
(define-constant EDGE-TYPE-PART-OF u5)
(define-constant EDGE-TYPE-SIMILAR-TO u6)

(define-constant STATUS-DRAFT u1)
(define-constant STATUS-PROPOSED u2)
(define-constant STATUS-VERIFIED u3)
(define-constant STATUS-DISPUTED u4)
(define-constant STATUS-DEPRECATED u5)

(define-constant MIN-REPUTATION u15)
(define-constant VERIFICATION-THRESHOLD u3)
(define-constant CONSENSUS-RATIO u70)

(define-data-var node-nonce uint u0)
(define-data-var edge-nonce uint u0)
(define-data-var platform-reputation-threshold uint u100)
(define-data-var knowledge-reward uint u1000)

(define-map knowledge-nodes
  { node-id: uint }
  {
    creator: principal,
    node-type: uint,
    title: (string-ascii 100),
    description: (string-ascii 800),
    content: (string-ascii 1200),
    domain: (string-ascii 50),
    tags: (list 5 (string-ascii 30)),
    created-at: uint,
    updated-at: uint,
    status: uint,
    verification-count: uint,
    dispute-count: uint,
    confidence-score: uint,
    citations: (list 3 (string-ascii 200)),
    version: uint
  }
)

(define-map knowledge-edges
  { edge-id: uint }
  {
    creator: principal,
    source-node: uint,
    target-node: uint,
    edge-type: uint,
    relationship-desc: (string-ascii 200),
    strength: uint,
    created-at: uint,
    status: uint,
    verification-count: uint,
    confidence-score: uint
  }
)

(define-map node-verifications
  { node-id: uint, verifier: principal }
  {
    verified-at: uint,
    accuracy-score: uint,
    relevance-score: uint,
    citation-quality: uint,
    comments: (string-ascii 300),
    overall-rating: uint
  }
)

(define-map edge-verifications
  { edge-id: uint, verifier: principal }
  {
    verified-at: uint,
    logical-correctness: uint,
    relationship-strength: uint,
    evidence-quality: uint,
    overall-rating: uint
  }
)

(define-map contributor-profiles
  { contributor: principal }
  {
    nodes-created: uint,
    edges-created: uint,
    verifications-done: uint,
    reputation-score: uint,
    expertise-domains: (list 8 (string-ascii 40)),
    total-contributions: uint,
    accuracy-rating: uint,
    knowledge-impact: uint
  }
)

(define-map knowledge-queries
  { query-id: uint }
  {
    querier: principal,
    query-type: uint,
    search-terms: (list 5 (string-ascii 50)),
    result-nodes: (list 10 uint),
    query-timestamp: uint,
    relevance-score: uint
  }
)

(define-map domain-statistics
  { domain: (string-ascii 50) }
  {
    node-count: uint,
    edge-count: uint,
    contributor-count: uint,
    average-confidence: uint,
    last-updated: uint
  }
)

(define-public (create-knowledge-node
  (node-type uint)
  (title (string-ascii 100))
  (description (string-ascii 800))
  (content (string-ascii 1200))
  (domain (string-ascii 50))
  (tags (list 5 (string-ascii 30)))
  (citations (list 3 (string-ascii 200)))
)
  (let (
    (node-id (+ (var-get node-nonce) u1))
    (creator tx-sender)
    (contributor-profile (default-to
      {nodes-created: u0, edges-created: u0, verifications-done: u0, reputation-score: u50, expertise-domains: (list), total-contributions: u0, accuracy-rating: u100, knowledge-impact: u0}
      (map-get? contributor-profiles {contributor: creator})
    ))
  )
    (asserts! (>= (get reputation-score contributor-profile) MIN-REPUTATION) ERR-INSUFFICIENT-REPUTATION)
    (asserts! (and (>= node-type u1) (<= node-type u5)) ERR-INVALID-INPUT)
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u10) ERR-INVALID-INPUT)
    (asserts! (> (len content) u20) ERR-INVALID-INPUT)
    (asserts! (> (len citations) u0) ERR-CITATION-REQUIRED)

    (map-set knowledge-nodes
      {node-id: node-id}
      {
        creator: creator,
        node-type: node-type,
        title: title,
        description: description,
        content: content,
        domain: domain,
        tags: tags,
        created-at: stacks-block-height,
        updated-at: stacks-block-height,
        status: STATUS-PROPOSED,
        verification-count: u0,
        dispute-count: u0,
        confidence-score: u50,
        citations: citations,
        version: u1
      }
    )

    (map-set contributor-profiles
      {contributor: creator}
      (merge contributor-profile {
        nodes-created: (+ (get nodes-created contributor-profile) u1),
        total-contributions: (+ (get total-contributions contributor-profile) u1)
      })
    )

    (let (
      (domain-stats (default-to
        {node-count: u0, edge-count: u0, contributor-count: u0, average-confidence: u50, last-updated: stacks-block-height}
        (map-get? domain-statistics {domain: domain})
      ))
    )
      (map-set domain-statistics
        {domain: domain}
        (merge domain-stats {
          node-count: (+ (get node-count domain-stats) u1),
          last-updated: stacks-block-height
        })
      )
    )

    (var-set node-nonce node-id)
    (ok node-id)
  )
)

(define-public (create-knowledge-edge
  (source-node uint)
  (target-node uint)
  (edge-type uint)
  (relationship-desc (string-ascii 200))
  (strength uint)
)
  (let (
    (edge-id (+ (var-get edge-nonce) u1))
    (creator tx-sender)
    (contributor-profile (default-to
      {nodes-created: u0, edges-created: u0, verifications-done: u0, reputation-score: u50, expertise-domains: (list), total-contributions: u0, accuracy-rating: u100, knowledge-impact: u0}
      (map-get? contributor-profiles {contributor: creator})
    ))
  )
    (asserts! (>= (get reputation-score contributor-profile) MIN-REPUTATION) ERR-INSUFFICIENT-REPUTATION)
    (asserts! (is-some (map-get? knowledge-nodes {node-id: source-node})) ERR-NODE-NOT-FOUND)
    (asserts! (is-some (map-get? knowledge-nodes {node-id: target-node})) ERR-NODE-NOT-FOUND)
    (asserts! (not (is-eq source-node target-node)) ERR-INVALID-INPUT)
    (asserts! (and (>= edge-type u1) (<= edge-type u6)) ERR-INVALID-RELATIONSHIP)
    (asserts! (and (>= strength u1) (<= strength u100)) ERR-INVALID-INPUT)
    (asserts! (> (len relationship-desc) u0) ERR-INVALID-INPUT)

    (map-set knowledge-edges
      {edge-id: edge-id}
      {
        creator: creator,
        source-node: source-node,
        target-node: target-node,
        edge-type: edge-type,
        relationship-desc: relationship-desc,
        strength: strength,
        created-at: stacks-block-height,
        status: STATUS-PROPOSED,
        verification-count: u0,
        confidence-score: u50
      }
    )

    (map-set contributor-profiles
      {contributor: creator}
      (merge contributor-profile {
        edges-created: (+ (get edges-created contributor-profile) u1),
        total-contributions: (+ (get total-contributions contributor-profile) u1)
      })
    )

    (var-set edge-nonce edge-id)
    (ok edge-id)
  )
)

(define-public (verify-knowledge-node
  (node-id uint)
  (accuracy-score uint)
  (relevance-score uint)
  (citation-quality uint)
  (comments (string-ascii 300))
)
  (let (
    (verifier tx-sender)
    (node (unwrap! (map-get? knowledge-nodes {node-id: node-id}) ERR-NODE-NOT-FOUND))
    (verifier-profile (default-to
      {nodes-created: u0, edges-created: u0, verifications-done: u0, reputation-score: u50, expertise-domains: (list), total-contributions: u0, accuracy-rating: u100, knowledge-impact: u0}
      (map-get? contributor-profiles {contributor: verifier})
    ))
    (overall-rating (/ (+ accuracy-score relevance-score citation-quality) u3))
  )
    (asserts! (not (is-eq verifier (get creator node))) ERR-NOT-AUTHORIZED)
    (asserts! (>= (get reputation-score verifier-profile) u30) ERR-INSUFFICIENT-REPUTATION)
    (asserts! (is-none (map-get? node-verifications {node-id: node-id, verifier: verifier})) ERR-ALREADY-VERIFIED)
    (asserts! (<= accuracy-score u100) ERR-INVALID-INPUT)
    (asserts! (<= relevance-score u100) ERR-INVALID-INPUT)
    (asserts! (<= citation-quality u100) ERR-INVALID-INPUT)

    (map-set node-verifications
      {node-id: node-id, verifier: verifier}
      {
        verified-at: stacks-block-height,
        accuracy-score: accuracy-score,
        relevance-score: relevance-score,
        citation-quality: citation-quality,
        comments: comments,
        overall-rating: overall-rating
      }
    )

    (let (
      (updated-verification-count (+ (get verification-count node) u1))
      (updated-confidence (/ (+ (* (get confidence-score node) (get verification-count node)) overall-rating) updated-verification-count))
      (new-status (if (>= updated-verification-count VERIFICATION-THRESHOLD) STATUS-VERIFIED (get status node)))
    )
      (map-set knowledge-nodes
        {node-id: node-id}
        (merge node {
          verification-count: updated-verification-count,
          confidence-score: updated-confidence,
          status: new-status,
          updated-at: stacks-block-height
        })
      )
    )

    (map-set contributor-profiles
      {contributor: verifier}
      (merge verifier-profile {
        verifications-done: (+ (get verifications-done verifier-profile) u1),
        reputation-score: (+ (get reputation-score verifier-profile) u5),
        total-contributions: (+ (get total-contributions verifier-profile) u1)
      })
    )

    (ok true)
  )
)

(define-public (verify-knowledge-edge
  (edge-id uint)
  (logical-correctness uint)
  (relationship-strength uint)
  (evidence-quality uint)
)
  (let (
    (verifier tx-sender)
    (edge (unwrap! (map-get? knowledge-edges {edge-id: edge-id}) ERR-EDGE-NOT-FOUND))
    (verifier-profile (default-to
      {nodes-created: u0, edges-created: u0, verifications-done: u0, reputation-score: u50, expertise-domains: (list), total-contributions: u0, accuracy-rating: u100, knowledge-impact: u0}
      (map-get? contributor-profiles {contributor: verifier})
    ))
    (overall-rating (/ (+ logical-correctness relationship-strength evidence-quality) u3))
  )
    (asserts! (not (is-eq verifier (get creator edge))) ERR-NOT-AUTHORIZED)
    (asserts! (>= (get reputation-score verifier-profile) u25) ERR-INSUFFICIENT-REPUTATION)
    (asserts! (is-none (map-get? edge-verifications {edge-id: edge-id, verifier: verifier})) ERR-ALREADY-VERIFIED)
    (asserts! (<= logical-correctness u100) ERR-INVALID-INPUT)
    (asserts! (<= relationship-strength u100) ERR-INVALID-INPUT)
    (asserts! (<= evidence-quality u100) ERR-INVALID-INPUT)

    (map-set edge-verifications
      {edge-id: edge-id, verifier: verifier}
      {
        verified-at: stacks-block-height,
        logical-correctness: logical-correctness,
        relationship-strength: relationship-strength,
        evidence-quality: evidence-quality,
        overall-rating: overall-rating
      }
    )

    (let (
      (updated-verification-count (+ (get verification-count edge) u1))
      (updated-confidence (/ (+ (* (get confidence-score edge) (get verification-count edge)) overall-rating) updated-verification-count))
      (new-status (if (>= updated-verification-count VERIFICATION-THRESHOLD) STATUS-VERIFIED (get status edge)))
    )
      (map-set knowledge-edges
        {edge-id: edge-id}
        (merge edge {
          verification-count: updated-verification-count,
          confidence-score: updated-confidence,
          status: new-status
        })
      )
    )

    (map-set contributor-profiles
      {contributor: verifier}
      (merge verifier-profile {
        verifications-done: (+ (get verifications-done verifier-profile) u1),
        reputation-score: (+ (get reputation-score verifier-profile) u3)
      })
    )

    (ok true)
  )
)

(define-public (query-knowledge-graph
  (search-terms (list 5 (string-ascii 50)))
  (query-type uint)
)
  (let (
    (query-id (+ (var-get node-nonce) (var-get edge-nonce)))
    (querier tx-sender)
  )
    (asserts! (> (len search-terms) u0) ERR-INVALID-INPUT)
    (asserts! (and (>= query-type u1) (<= query-type u3)) ERR-INVALID-INPUT)

    (map-set knowledge-queries
      {query-id: query-id}
      {
        querier: querier,
        query-type: query-type,
        search-terms: search-terms,
        result-nodes: (list),
        query-timestamp: stacks-block-height,
        relevance-score: u0
      }
    )

    (ok query-id)
  )
)

(define-public (update-node-content
  (node-id uint)
  (new-content (string-ascii 1200))
  (new-citations (list 3 (string-ascii 200)))
)
  (let (
    (node (unwrap! (map-get? knowledge-nodes {node-id: node-id}) ERR-NODE-NOT-FOUND))
    (updater tx-sender)
  )
    (asserts! (is-eq updater (get creator node)) ERR-NOT-AUTHORIZED)
    (asserts! (> (len new-content) u20) ERR-INVALID-INPUT)
    (asserts! (> (len new-citations) u0) ERR-CITATION-REQUIRED)

    (map-set knowledge-nodes
      {node-id: node-id}
      (merge node {
        content: new-content,
        citations: new-citations,
        updated-at: stacks-block-height,
        version: (+ (get version node) u1),
        status: STATUS-PROPOSED,
        verification-count: u0,
        confidence-score: u50
      })
    )

    (ok true)
  )
)

(define-public (dispute-knowledge-node
  (node-id uint)
  (dispute-reason (string-ascii 300))
)
  (let (
    (node (unwrap! (map-get? knowledge-nodes {node-id: node-id}) ERR-NODE-NOT-FOUND))
    (disputer tx-sender)
    (disputer-profile (default-to
      {nodes-created: u0, edges-created: u0, verifications-done: u0, reputation-score: u50, expertise-domains: (list), total-contributions: u0, accuracy-rating: u100, knowledge-impact: u0}
      (map-get? contributor-profiles {contributor: disputer})
    ))
  )
    (asserts! (not (is-eq disputer (get creator node))) ERR-NOT-AUTHORIZED)
    (asserts! (>= (get reputation-score disputer-profile) u40) ERR-INSUFFICIENT-REPUTATION)
    (asserts! (> (len dispute-reason) u10) ERR-INVALID-INPUT)

    (map-set knowledge-nodes
      {node-id: node-id}
      (merge node {
        dispute-count: (+ (get dispute-count node) u1),
        status: STATUS-DISPUTED,
        updated-at: stacks-block-height
      })
    )

    (ok true)
  )
)

(define-public (update-contributor-expertise
  (contributor principal)
  (expertise-domains (list 8 (string-ascii 40)))
)
  (let (
    (profile (default-to
      {nodes-created: u0, edges-created: u0, verifications-done: u0, reputation-score: u50, expertise-domains: (list), total-contributions: u0, accuracy-rating: u100, knowledge-impact: u0}
      (map-get? contributor-profiles {contributor: contributor})
    ))
  )
    (asserts! (is-eq tx-sender contributor) ERR-NOT-AUTHORIZED)

    (map-set contributor-profiles
      {contributor: contributor}
      (merge profile {expertise-domains: expertise-domains})
    )

    (ok true)
  )
)

(define-public (reward-quality-contribution
  (contributor principal)
)
  (let (
    (profile (unwrap! (map-get? contributor-profiles {contributor: contributor}) ERR-NOT-CONTRIBUTOR))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (>= (get accuracy-rating profile) u85) ERR-INSUFFICIENT-REPUTATION)
    (asserts! (>= (get total-contributions profile) u10) ERR-INVALID-INPUT)

    (try! (stx-transfer? (var-get knowledge-reward) (as-contract tx-sender) contributor))

    (map-set contributor-profiles
      {contributor: contributor}
      (merge profile {
        reputation-score: (+ (get reputation-score profile) u20),
        knowledge-impact: (+ (get knowledge-impact profile) u100)
      })
    )

    (ok true)
  )
)

(define-read-only (get-knowledge-node (node-id uint))
  (map-get? knowledge-nodes {node-id: node-id})
)

(define-read-only (get-knowledge-edge (edge-id uint))
  (map-get? knowledge-edges {edge-id: edge-id})
)

(define-read-only (get-contributor-profile (contributor principal))
  (map-get? contributor-profiles {contributor: contributor})
)

(define-read-only (get-node-verification (node-id uint) (verifier principal))
  (map-get? node-verifications {node-id: node-id, verifier: verifier})
)

(define-read-only (get-edge-verification (edge-id uint) (verifier principal))
  (map-get? edge-verifications {edge-id: edge-id, verifier: verifier})
)

(define-read-only (get-domain-statistics (domain (string-ascii 50)))
  (map-get? domain-statistics {domain: domain})
)

(define-read-only (get-knowledge-query (query-id uint))
  (map-get? knowledge-queries {query-id: query-id})
)

(define-read-only (get-platform-stats)
  {
    total-nodes: (var-get node-nonce),
    total-edges: (var-get edge-nonce),
    reputation-threshold: (var-get platform-reputation-threshold),
    knowledge-reward: (var-get knowledge-reward),
    min-reputation: MIN-REPUTATION,
    verification-threshold: VERIFICATION-THRESHOLD
  }
)

(define-public (set-reputation-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> new-threshold u0) ERR-INVALID-INPUT)
    (var-set platform-reputation-threshold new-threshold)
    (ok true)
  )
)

(define-public (set-knowledge-reward (new-reward uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> new-reward u0) ERR-INVALID-INPUT)
    (var-set knowledge-reward new-reward)
    (ok true)
  )
)

(begin
  (var-set platform-reputation-threshold u100)
  (var-set knowledge-reward u1000)
)