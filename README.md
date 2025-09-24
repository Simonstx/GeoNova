# GeoNova 🌍

**Mint Location-Based NFTs in Real-Time with Dynamic Pricing & Multi-Signature Governance**

GeoNova is a revolutionary platform that allows users to mint NFTs tied to real-world locations and timestamps, creating unique digital collectibles for tourism, conferences, art installations, and event memorabilia. Now featuring dynamic pricing based on zone popularity, time of day, special events, and multi-signature governance for collaborative zone management.

## 🚀 Features

- **GPS-based NFT Minting**: Mint NFTs only when physically present at specific locations
- **Dynamic Pricing System**: Variable minting costs based on popularity, time, and events
- **Multi-Signature Zone Creation**: Community governance and partnership support for zone management
- **Real-time Verification**: Location and timestamp verification for authentic collectibles
- **Zone Management**: Configurable mintable zones with custom parameters and collaborative oversight
- **Cooldown Protection**: Anti-spam mechanisms with configurable mint cooldowns
- **Limited Editions**: Restricted minting per zone for true scarcity
- **One Per User Per Zone**: Each user can mint only once per location zone
- **Popularity-Based Pricing**: Higher prices for popular zones, incentivizing exploration
- **Time-Based Pricing**: Premium hours command higher prices
- **Special Event Multipliers**: Dynamic pricing for special occasions

## 🤝 Multi-Signature Governance Features

### Multi-Sig Zone Creation
- **Partnership Support**: Multiple organizations can collaborate on zone creation
- **Community Governance**: Decentralized decision-making for high-value locations
- **Signature Requirements**: Configurable signature thresholds for zone approval
- **Proposal System**: Submit zone proposals requiring multiple approvals
- **Transparency**: All signatures and proposals are recorded on-chain

### Governance Benefits
- **Shared Ownership**: Multiple parties can co-manage premium locations
- **Risk Distribution**: Distributed responsibility for zone management decisions
- **Community Trust**: Democratic approval process for new zones
- **Partnership Opportunities**: Enable collaborations between tourism boards, event organizers, and businesses

## 💰 Dynamic Pricing Features

### Popularity Tiers
- **Tier 1**: Initial pricing for new zones
- **Tier 2**: Increased pricing after reaching mint threshold
- **Tier 3**: Premium pricing for highly popular locations

### Time-Based Pricing
- Configure different prices for different hours of the day
- Peak hours (rush hour, lunch time) can have higher multipliers
- Off-peak hours can offer discounted rates

### Special Event Multipliers
- Real-time pricing adjustments for conferences, festivals, or special occasions
- Owner-controlled multipliers for dynamic market response

## 🛠 Technical Stack

- **Smart Contract**: Clarity (Stacks Blockchain)
- **Development**: Clarinet CLI
- **Testing**: Clarinet test suite
- **Deployment**: Stacks Mainnet/Testnet
- **Payment**: STX token integration
- **Governance**: Multi-signature proposal system

## 📋 Smart Contract Functions

### Multi-Signature Functions
- `add-authorized-signer`: Add authorized signers for multi-sig operations (owner only)
- `remove-authorized-signer`: Remove authorized signers (owner only)
- `set-signature-threshold`: Configure required signature count (owner only)
- `propose-zone-creation`: Submit zone creation proposal requiring multi-sig approval
- `sign-zone-proposal`: Sign a pending zone proposal (authorized signers only)
- `execute-zone-proposal`: Execute approved zone proposal (anyone can trigger)
- `get-zone-proposal`: Retrieve proposal details and signature status

### Public Functions
- `add-mintable-zone`: Create new mintable locations with pricing parameters (owner only)
- `set-pricing-tier`: Configure popularity-based pricing tiers (owner only)
- `set-time-based-pricing`: Set hourly pricing multipliers (owner only)
- `set-special-event-multiplier`: Update event-based pricing (owner only)
- `toggle-zone-status`: Activate/deactivate zones (owner only)
- `mint-location-nft`: Mint NFT at valid location with payment
- `set-mint-cooldown`: Update global cooldown period (owner only)
- `set-base-mint-price`: Update base pricing (owner only)

### Read-Only Functions
- `get-current-mint-price`: Calculate real-time mint price for zone
- `get-zone-info`: Retrieve zone details including pricing
- `get-pricing-tier`: Get tier information for popularity pricing
- `get-time-pricing`: Get hourly pricing multipliers
- `get-nft-info`: Get NFT metadata, location data, and mint price
- `can-user-mint`: Check if user can mint (cooldown status)
- `has-user-minted-in-zone`: Verify user mint status per zone
- `is-authorized-signer`: Check if principal is authorized signer
- `get-signature-threshold`: Get required signature count

## 🏗 Installation & Setup

1. **Install Clarinet**
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/hirosystems/clarinet/main/install.sh | sh
   ```

2. **Clone Repository**
   ```bash
   git clone <repository-url>
   cd geonova
   ```

3. **Check Contract**
   ```bash
   clarinet check
   ```

4. **Run Tests**
   ```bash
   clarinet test
   ```

## 📍 Usage Examples

### Setting Up Multi-Signature Governance
```clarity
;; Add authorized signers (owner only)
(contract-call? .geonova add-authorized-signer 'SP1ABC...)
(contract-call? .geonova add-authorized-signer 'SP2DEF...)
(contract-call? .geonova add-authorized-signer 'SP3GHI...)

;; Set signature threshold (require 2 out of 3 signatures)
(contract-call? .geonova set-signature-threshold u2)
```

### Creating Zone Proposal (Multi-Sig Process)
```clarity
;; Step 1: Submit zone proposal
(contract-call? .geonova propose-zone-creation
  u1                    ;; proposal-id
  u1                    ;; zone-id
  "Times Square NYC"    ;; name
  404852000             ;; latitude * 10^7
  -739776000            ;; longitude * 10^7
  u100                  ;; 100 meter radius
  u1000                 ;; max 1000 mints
  u1000000              ;; base price (1 STX)
  u150                  ;; popularity multiplier (1.5x)
  true                  ;; enable-time-pricing
  u100                  ;; special event multiplier (1.0x default)
)

;; Step 2: Authorized signers approve proposal
(contract-call? .geonova sign-zone-proposal u1) ;; First signer
(contract-call? .geonova sign-zone-proposal u1) ;; Second signer

;; Step 3: Execute approved proposal (anyone can trigger)
(contract-call? .geonova execute-zone-proposal u1)
```

### Adding a Mintable Zone (Traditional Owner-Only Method)
```clarity
(contract-call? .geonova add-mintable-zone 
  u1                    ;; zone-id
  "Central Park NYC"    ;; name
  407829000             ;; latitude * 10^7
  -739447000            ;; longitude * 10^7
  u200                  ;; 200 meter radius
  u500                  ;; max 500 mints
  u2000000              ;; base price (2 STX)
  u120                  ;; popularity multiplier (1.2x)
  false                 ;; disable time-pricing
  u100                  ;; special event multiplier (1.0x default)
)
```

### Setting Up Pricing Tiers
```clarity
;; Tier 1: After 100 mints, price increases by 1.5x
(contract-call? .geonova set-pricing-tier u1 u1 u100 u150)

;; Tier 2: After 500 mints, price increases by 2x
(contract-call? .geonova set-pricing-tier u1 u2 u500 u200)

;; Tier 3: After 800 mints, price increases by 3x
(contract-call? .geonova set-pricing-tier u1 u3 u800 u300)
```

### Configuring Time-Based Pricing
```clarity
;; Peak hours (9 AM): 2x multiplier
(contract-call? .geonova set-time-based-pricing u1 u9 u200)

;; Lunch hour (12 PM): 1.5x multiplier
(contract-call? .geonova set-time-based-pricing u1 u12 u150)

;; Off-peak (3 AM): 0.5x multiplier
(contract-call? .geonova set-time-based-pricing u1 u3 u50)
```

### Minting an NFT (User pays calculated price)
```clarity
(contract-call? .geonova mint-location-nft 
  u1 
  404852050             ;; User's latitude
  -739775950            ;; User's longitude
  "ipfs://QmHash..."    ;; Metadata URI
)
```

### Checking Proposal Status
```clarity
(contract-call? .geonova get-zone-proposal u1)
```

### Checking Current Price
```clarity
(contract-call? .geonova get-current-mint-price u1)
```

## 💎 Pricing Algorithm

The final mint price is calculated as:
```
Final Price = Base Price × (Popularity Multiplier × Time Multiplier × Event Multiplier) ÷ 10,000
```

**Example Calculation:**
- Base Price: 1 STX (1,000,000 microSTX)
- Popularity Multiplier: 150% (150)
- Time Multiplier: 200% (200) 
- Event Multiplier: 100% (100)
- Final Price: 1,000,000 × (150 × 200 × 100) ÷ 10,000 ÷ 100 = 3 STX

## 🔒 Security Features

- **Coordinate Validation**: Ensures valid GPS coordinates
- **Access Control**: Owner-only administrative functions with multi-sig governance option
- **Multi-Signature Security**: Prevents single point of failure for critical zone creation
- **Signature Verification**: Cryptographic proof of approvals from authorized signers
- **Cooldown Protection**: Prevents spam minting
- **Zone Verification**: Confirms user location within zone radius
- **Duplicate Prevention**: One mint per user per zone
- **Payment Security**: STX transfer validation and error handling
- **Input Validation**: Comprehensive parameter checking for all pricing and governance inputs

## 🎯 Use Cases

### Traditional Use Cases
- **Tourism**: Collect NFTs from famous landmarks with premium pricing
- **Conferences**: Event attendance verification with time-sensitive pricing
- **Art Installations**: Location-specific art pieces with dynamic valuation
- **Gaming**: Real-world treasure hunts with escalating rewards
- **Marketing**: Location-based promotional campaigns with surge pricing

### Multi-Sig Governance Use Cases
- **Tourism Partnerships**: Tourism boards and local businesses collaborate on landmark zones
- **Conference Consortiums**: Multiple event organizers jointly manage conference districts
- **Art Collectives**: Artist groups and galleries co-create installation zones
- **Municipal Partnerships**: City governments and business districts jointly manage zones
- **Brand Collaborations**: Multiple brands coordinate marketing campaigns in shared zones

## 📈 Contract Architecture

The contract uses efficient data structures with enhanced pricing and governance capabilities:
- `mintable-zones`: Zone configuration including pricing parameters
- `zone-pricing-tiers`: Popularity-based pricing tiers
- `time-based-pricing`: Hourly pricing multipliers
- `location-nfts`: NFT ownership, metadata, and mint price records
- `user-last-mint-time`: Cooldown tracking
- `zone-user-mints`: Per-zone minting records
- `authorized-signers`: Multi-signature governance participants
- `zone-proposals`: Pending zone creation proposals
- `proposal-signatures`: Signature tracking for proposals

## 🧪 Testing

Run the test suite to verify all functionality including pricing calculations and multi-sig governance:
```bash
clarinet test tests/geonova_test.ts
```

## 🚀 Deployment

Deploy to Stacks testnet:
```bash
clarinet deploy --testnet
```

---

# GeoNova Future Feature Roadmap 🚀

## 1. ✅ **Dynamic Pricing Zones** (IMPLEMENTED)
Variable minting costs based on zone popularity, time of day, or special events. Premium locations command higher prices while incentivizing discovery of lesser-known areas.

## 2. ✅ **Multi-Signature Zone Creation** (IMPLEMENTED)
Add multi-sig functionality for zone creation, allowing community governance or partnerships between organizations to collaboratively manage high-value locations.

## 3. **Time-Based Zone Activation**
Create scheduling system for zones that automatically activate/deactivate based on timestamps, perfect for conferences, festivals, or temporary art installations.

## 4. **NFT Staking and Rewards**
Allow users to stake their location NFTs to earn STX rewards, with higher rewards for rarer locations or complete collection sets.

## 5. **Cross-Chain Bridge Integration**
Enable bridging GeoNova NFTs to other blockchains (Ethereum, Polygon) for broader ecosystem compatibility and enhanced liquidity.

## 6. **Augmented Reality Metadata**
Extend NFT metadata to include AR content, 3D models, or interactive experiences that can be viewed when revisiting the mint location.

## 7. **Social Features and Leaderboards**
Add social proof systems with user profiles, collection showcases, location discovery leaderboards, and sharing mechanisms.

## 8. **Batch Minting for Events**
Implement batch minting functionality for large events, allowing organizers to pre-mint NFTs for attendees with proof-of-attendance verification.

## 9. **Geographic Collections and Quests**
Create collection systems where users can complete geographic challenges (visit all landmarks in a city) to unlock special rewards or rare NFTs.

## 10. **AI-Powered Location Recommendations**
Integrate AI recommendation engine that suggests new zones to visit based on user minting history, preferences, and proximity to create personalized exploration experiences.

**Built with ❤️ on Stacks Blockchain**