# GeoNova 🌍

**Mint Location-Based NFTs in Real-Time**

GeoNova is a revolutionary platform that allows users to mint NFTs tied to real-world locations and timestamps, creating unique digital collectibles for tourism, conferences, art installations, and event memorabilia.

## 🚀 Features

- **GPS-based NFT Minting**: Mint NFTs only when physically present at specific locations
- **Real-time Verification**: Location and timestamp verification for authentic collectibles
- **Zone Management**: Configurable mintable zones with custom parameters
- **Cooldown Protection**: Anti-spam mechanisms with configurable mint cooldowns
- **Limited Editions**: Restricted minting per zone for true scarcity
- **One Per User Per Zone**: Each user can mint only once per location zone

## 🛠 Technical Stack

- **Smart Contract**: Clarity (Stacks Blockchain)
- **Development**: Clarinet CLI
- **Testing**: Clarinet test suite
- **Deployment**: Stacks Mainnet/Testnet

## 📋 Smart Contract Functions

### Public Functions
- `add-mintable-zone`: Create new mintable locations (owner only)
- `toggle-zone-status`: Activate/deactivate zones (owner only)
- `mint-location-nft`: Mint NFT at valid location
- `set-mint-cooldown`: Update global cooldown period (owner only)

### Read-Only Functions
- `get-zone-info`: Retrieve zone details
- `get-nft-info`: Get NFT metadata and location data
- `can-user-mint`: Check if user can mint (cooldown status)
- `has-user-minted-in-zone`: Verify user mint status per zone

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

### Adding a Mintable Zone
```clarity
(contract-call? .geonova add-mintable-zone 
  u1 
  "Times Square NYC" 
  404852000  ;; Latitude * 10^7
  -739776000 ;; Longitude * 10^7
  u100       ;; 100 meter radius
  u1000      ;; Max 1000 mints
)
```

### Minting an NFT
```clarity
(contract-call? .geonova mint-location-nft 
  u1 
  404852050  ;; User's latitude
  -739775950 ;; User's longitude
  "ipfs://QmHash..." ;; Metadata URI
)
```

## 🔒 Security Features

- **Coordinate Validation**: Ensures valid GPS coordinates
- **Access Control**: Owner-only administrative functions
- **Cooldown Protection**: Prevents spam minting
- **Zone Verification**: Confirms user location within zone radius
- **Duplicate Prevention**: One mint per user per zone

## 🎯 Use Cases

- **Tourism**: Collect NFTs from famous landmarks
- **Conferences**: Event attendance verification
- **Art Installations**: Location-specific art pieces
- **Gaming**: Real-world treasure hunts
- **Marketing**: Location-based promotional campaigns

## 📈 Contract Architecture

The contract uses efficient data structures:
- `mintable-zones`: Zone configuration and status
- `location-nfts`: NFT ownership and metadata
- `user-last-mint`: Cooldown tracking
- `zone-user-mints`: Per-zone minting records

## 🧪 Testing

Run the test suite to verify all functionality:
```bash
clarinet test tests/geonova_test.ts
```

## 🚀 Deployment

Deploy to Stacks testnet:
```bash
clarinet deploy --testnet
```

## 📄 License

MIT License - see LICENSE file for details

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request


# GeoNova Future Feature Roadmap 🚀

## 1. **Dynamic Pricing Zones**
Implement variable minting costs based on zone popularity, time of day, or special events. Premium locations could command higher prices while incentivizing discovery of lesser-known areas.

## 2. **Multi-Signature Zone Creation**
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